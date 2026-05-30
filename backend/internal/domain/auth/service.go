package auth

import (
	"context"
	"errors"
	"net"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrInvalidRefresh     = errors.New("invalid refresh token")
	ErrEmailTaken         = errors.New("email is already registered")
)

type Service struct {
	db           *pgxpool.Pool
	tokens       TokenManager
	passwordCost int
}

func NewService(db *pgxpool.Pool, tokens TokenManager, passwordCost int) *Service {
	return &Service{db: db, tokens: tokens, passwordCost: passwordCost}
}

func (s *Service) Register(ctx context.Context, input RegisterInput, userAgent string, ip string) (AuthResponse, error) {
	input.Email = normalizeEmail(input.Email)
	input.Name = strings.TrimSpace(input.Name)
	input.CompanyName = strings.TrimSpace(input.CompanyName)

	if input.CompanyName == "" {
		input.CompanyName = "Quoter Company"
	}
	if input.Name == "" || input.Email == "" || len(input.Password) < 10 {
		return AuthResponse{}, errors.New("name, valid email, and 10+ character password are required")
	}

	passwordHash, err := HashPassword(input.Password, s.passwordCost)
	if err != nil {
		return AuthResponse{}, err
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return AuthResponse{}, err
	}
	defer tx.Rollback(ctx)

	var companyID uuid.UUID
	if err := tx.QueryRow(ctx, `
		INSERT INTO companies (name)
		VALUES ($1)
		RETURNING id
	`, input.CompanyName).Scan(&companyID); err != nil {
		return AuthResponse{}, err
	}

	user := User{CompanyID: companyID, Email: input.Email, Name: input.Name, Role: "admin", Status: "active"}
	if err := tx.QueryRow(ctx, `
		INSERT INTO users (company_id, email, name, password_hash, role, status)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`, user.CompanyID, user.Email, user.Name, passwordHash, user.Role, user.Status).Scan(&user.ID, &user.CreatedAt); err != nil {
		if isUniqueViolation(err) {
			return AuthResponse{}, ErrEmailTaken
		}
		return AuthResponse{}, err
	}

	if err := seedDefaultCatalog(ctx, tx, companyID); err != nil {
		return AuthResponse{}, err
	}

	response, err := s.createSession(ctx, tx, user, userAgent, ip)
	if err != nil {
		return AuthResponse{}, err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO audit_logs (company_id, user_id, action, entity_type, entity_id, ip_address, user_agent)
		VALUES ($1, $2, 'auth.register', 'user', $2, $3, $4)
	`, user.CompanyID, user.ID, normalizeIP(ip), userAgent); err != nil {
		return AuthResponse{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return AuthResponse{}, err
	}
	return response, nil
}

func (s *Service) Login(ctx context.Context, input LoginInput, userAgent string, ip string) (AuthResponse, error) {
	email := normalizeEmail(input.Email)
	var user User
	var passwordHash string
	if err := s.db.QueryRow(ctx, `
		SELECT id, company_id, email, name, role, status, password_hash, created_at
		FROM users
		WHERE email=$1 AND deleted_at IS NULL
	`, email).Scan(&user.ID, &user.CompanyID, &user.Email, &user.Name, &user.Role, &user.Status, &passwordHash, &user.CreatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AuthResponse{}, ErrInvalidCredentials
		}
		return AuthResponse{}, err
	}
	if user.Status != "active" || !CheckPassword(passwordHash, input.Password) {
		return AuthResponse{}, ErrInvalidCredentials
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return AuthResponse{}, err
	}
	defer tx.Rollback(ctx)

	response, err := s.createSession(ctx, tx, user, userAgent, ip)
	if err != nil {
		return AuthResponse{}, err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO audit_logs (company_id, user_id, action, entity_type, entity_id, ip_address, user_agent)
		VALUES ($1, $2, 'auth.login', 'user', $2, $3, $4)
	`, user.CompanyID, user.ID, normalizeIP(ip), userAgent); err != nil {
		return AuthResponse{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return AuthResponse{}, err
	}
	return response, nil
}

func (s *Service) Refresh(ctx context.Context, input RefreshInput, userAgent string, ip string) (AuthResponse, error) {
	if strings.TrimSpace(input.RefreshToken) == "" {
		return AuthResponse{}, ErrInvalidRefresh
	}
	hashed := HashRefreshToken(input.RefreshToken)

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return AuthResponse{}, err
	}
	defer tx.Rollback(ctx)

	var sessionID uuid.UUID
	var user User
	if err := tx.QueryRow(ctx, `
		SELECT s.id, u.id, u.company_id, u.email, u.name, u.role, u.status, u.created_at
		FROM user_sessions s
		JOIN users u ON u.id = s.user_id
		WHERE s.refresh_token_hash=$1
		  AND s.revoked_at IS NULL
		  AND s.expires_at > now()
		  AND u.deleted_at IS NULL
		FOR UPDATE OF s
	`, hashed).Scan(&sessionID, &user.ID, &user.CompanyID, &user.Email, &user.Name, &user.Role, &user.Status, &user.CreatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AuthResponse{}, ErrInvalidRefresh
		}
		return AuthResponse{}, err
	}
	if user.Status != "active" {
		return AuthResponse{}, ErrInvalidRefresh
	}

	response, err := s.createSession(ctx, tx, user, userAgent, ip)
	if err != nil {
		return AuthResponse{}, err
	}
	var newSessionID uuid.UUID
	if err := tx.QueryRow(ctx, `
		SELECT id FROM user_sessions WHERE refresh_token_hash=$1
	`, HashRefreshToken(response.RefreshToken)).Scan(&newSessionID); err != nil {
		return AuthResponse{}, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE user_sessions
		SET revoked_at=now(), rotated_to_session_id=$2
		WHERE id=$1
	`, sessionID, newSessionID); err != nil {
		return AuthResponse{}, err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO audit_logs (company_id, user_id, action, entity_type, entity_id, ip_address, user_agent)
		VALUES ($1, $2, 'auth.refresh', 'user_session', $3, $4, $5)
	`, user.CompanyID, user.ID, sessionID, normalizeIP(ip), userAgent); err != nil {
		return AuthResponse{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return AuthResponse{}, err
	}
	return response, nil
}

func (s *Service) Logout(ctx context.Context, input LogoutInput, claims Claims) error {
	token := strings.TrimSpace(input.RefreshToken)
	if token == "" {
		return nil
	}
	_, err := s.db.Exec(ctx, `
		UPDATE user_sessions
		SET revoked_at=now()
		WHERE company_id=$1 AND user_id=$2 AND refresh_token_hash=$3 AND revoked_at IS NULL
	`, claims.CompanyID, claims.UserID, HashRefreshToken(token))
	return err
}

func (s *Service) Me(ctx context.Context, claims Claims) (MeResponse, error) {
	var response MeResponse
	if err := s.db.QueryRow(ctx, `
		SELECT u.id, u.company_id, u.email, u.name, u.role, u.status, u.created_at, c.name
		FROM users u
		JOIN companies c ON c.id = u.company_id
		WHERE u.id=$1 AND u.company_id=$2 AND u.deleted_at IS NULL
	`, claims.UserID, claims.CompanyID).Scan(
		&response.User.ID,
		&response.User.CompanyID,
		&response.User.Email,
		&response.User.Name,
		&response.User.Role,
		&response.User.Status,
		&response.User.CreatedAt,
		&response.CompanyName,
	); err != nil {
		return MeResponse{}, err
	}
	return response, nil
}

func (s *Service) createSession(ctx context.Context, tx pgx.Tx, user User, userAgent string, ip string) (AuthResponse, error) {
	refreshToken, err := GenerateRefreshToken()
	if err != nil {
		return AuthResponse{}, err
	}
	accessToken, expiresAt, err := s.tokens.SignAccessToken(user)
	if err != nil {
		return AuthResponse{}, err
	}
	expiresRefresh := time.Now().UTC().Add(s.tokens.RefreshTTL())
	if _, err := tx.Exec(ctx, `
		INSERT INTO user_sessions (
			company_id, user_id, refresh_token_hash, user_agent, ip_address, expires_at
		)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, user.CompanyID, user.ID, HashRefreshToken(refreshToken), userAgent, normalizeIP(ip), expiresRefresh); err != nil {
		return AuthResponse{}, err
	}
	return AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresAt:    expiresAt,
		User:         user,
	}, nil
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func normalizeIP(ip string) any {
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return nil
	}
	return parsed.String()
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
