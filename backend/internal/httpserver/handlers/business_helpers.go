package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"quoter/backend/internal/domain/catalog"
	"quoter/backend/internal/httpserver/middleware"
	postgresrepo "quoter/backend/internal/repository/postgres"
)

type BusinessHandler struct {
	db      *pgxpool.Pool
	catalog *catalog.Service
}

func NewBusinessHandler(db *pgxpool.Pool) BusinessHandler {
	return BusinessHandler{
		db:      db,
		catalog: catalog.NewService(postgresrepo.NewCatalogRepository(db)),
	}
}

type actor struct {
	CompanyID uuid.UUID
	UserID    uuid.UUID
	Role      string
}

type listResponse[T any] struct {
	Items []T `json:"items"`
}

func currentActor(c *gin.Context) (actor, bool) {
	claims, ok := middleware.Claims(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing claims"})
		return actor{}, false
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid company claim"})
		return actor{}, false
	}
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user claim"})
		return actor{}, false
	}
	return actor{CompanyID: companyID, UserID: userID, Role: claims.Role}, true
}

func pathUUID(c *gin.Context, name string) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param(name))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("invalid %s", name)})
		return uuid.Nil, false
	}
	return id, true
}

func bindJSON(c *gin.Context, target any) bool {
	if err := c.ShouldBindJSON(target); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON body"})
		return false
	}
	return true
}

func writeDBError(c *gin.Context, err error, notFoundMessage string) {
	if err == nil {
		return
	}
	if errors.Is(err, pgx.ErrNoRows) {
		c.JSON(http.StatusNotFound, gin.H{"error": notFoundMessage})
		return
	}
	c.JSON(http.StatusInternalServerError, gin.H{"error": "database operation failed"})
}

func optionalString(value string) *string {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	return &value
}

func optionalUUID(value string) *uuid.UUID {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	id, err := uuid.Parse(value)
	if err != nil {
		return nil
	}
	return &id
}

func roundMoney(value float64) float64 {
	return math.Round(value*100) / 100
}

func parseNumericString(value string) (float64, bool) {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0, false
	}
	parsed, err := strconv.ParseFloat(value, 64)
	return parsed, err == nil
}

func jsonSnapshot(value any) []byte {
	raw, err := json.Marshal(value)
	if err != nil {
		return []byte(`{}`)
	}
	return raw
}

func writeAudit(db *pgxpool.Pool, c *gin.Context, a actor, action string, entityType string, entityID uuid.UUID, metadata any) {
	_, _ = db.Exec(c.Request.Context(), `
		INSERT INTO audit_logs (company_id, user_id, action, entity_type, entity_id, metadata, ip_address, user_agent)
		VALUES ($1, $2, $3, $4, $5, $6, NULLIF($7, '')::inet, $8)
	`, a.CompanyID, a.UserID, action, entityType, nullableUUID(entityID), jsonSnapshot(metadata), c.ClientIP(), c.GetHeader("User-Agent"))
}

func nullableUUID(id uuid.UUID) any {
	if id == uuid.Nil {
		return nil
	}
	return id
}

func defaultStatus(status string, fallback string) string {
	status = strings.TrimSpace(status)
	if status == "" {
		return fallback
	}
	return status
}

func clampUnit(value float64, fallback float64) float64 {
	if value == 0 && fallback != 0 {
		return fallback
	}
	if value < 0 {
		return 0
	}
	if value > 1 {
		return 1
	}
	return value
}

func nowUTC() time.Time {
	return time.Now().UTC()
}

type optionalTimeScanner struct {
	target **time.Time
}

func timePtrScanner(target **time.Time) *optionalTimeScanner {
	return &optionalTimeScanner{target: target}
}

func (s *optionalTimeScanner) Scan(value any) error {
	if value == nil {
		*s.target = nil
		return nil
	}
	switch v := value.(type) {
	case time.Time:
		*s.target = &v
	case string:
		parsed, err := time.Parse(time.RFC3339Nano, v)
		if err != nil {
			return err
		}
		*s.target = &parsed
	case []byte:
		parsed, err := time.Parse(time.RFC3339Nano, string(v))
		if err != nil {
			return err
		}
		*s.target = &parsed
	default:
		return fmt.Errorf("unsupported time value %T", value)
	}
	return nil
}
