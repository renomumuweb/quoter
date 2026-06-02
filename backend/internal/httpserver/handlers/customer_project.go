package handlers

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type customerPayload struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	Phone     *string   `json:"phone,omitempty"`
	Email     *string   `json:"email,omitempty"`
	Address   *string   `json:"address,omitempty"`
	Notes     *string   `json:"notes,omitempty"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type customerInput struct {
	Name    string  `json:"name"`
	Phone   *string `json:"phone"`
	Email   *string `json:"email"`
	Address *string `json:"address"`
	Notes   *string `json:"notes"`
}

func (h BusinessHandler) ListCustomers(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}

	search := strings.TrimSpace(c.Query("q"))
	args := []any{a.CompanyID}
	query := `
		SELECT id, name, COALESCE(phone, ''), COALESCE(email, ''), COALESCE(address, ''), COALESCE(notes, ''),
		       status, created_at, updated_at
		FROM customers
		WHERE company_id=$1 AND deleted_at IS NULL
	`
	if search != "" {
		args = append(args, "%"+strings.ToLower(search)+"%")
		query += ` AND (lower(name) LIKE $2 OR lower(COALESCE(email, '')) LIKE $2 OR lower(COALESCE(phone, '')) LIKE $2)`
	}
	query += ` ORDER BY updated_at DESC, created_at DESC`

	rows, err := h.db.Query(c.Request.Context(), query, args...)
	if err != nil {
		writeDBError(c, err, "customers not found")
		return
	}
	defer rows.Close()

	items := make([]customerPayload, 0)
	for rows.Next() {
		item, err := scanCustomer(rows)
		if err != nil {
			writeDBError(c, err, "customers not found")
			return
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeDBError(c, err, "customers not found")
		return
	}
	c.JSON(http.StatusOK, listResponse[customerPayload]{Items: items})
}

func (h BusinessHandler) CreateCustomer(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	var input customerInput
	if !bindJSON(c, &input) {
		return
	}
	input.Name = strings.TrimSpace(input.Name)
	if input.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "customer name is required"})
		return
	}

	var item customerPayload
	err := h.db.QueryRow(c.Request.Context(), `
		INSERT INTO customers (company_id, name, phone, email, address, notes, created_by)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, name, COALESCE(phone, ''), COALESCE(email, ''), COALESCE(address, ''), COALESCE(notes, ''),
		          status, created_at, updated_at
	`, a.CompanyID, input.Name, input.Phone, input.Email, input.Address, input.Notes, a.UserID).Scan(
		&item.ID, &item.Name, newOptionalString(&item.Phone), newOptionalString(&item.Email),
		newOptionalString(&item.Address), newOptionalString(&item.Notes), &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "customer not found")
		return
	}
	writeAudit(h.db, c, a, "customers.create", "customer", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusCreated, item)
}

func (h BusinessHandler) GetCustomer(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	item, err := h.getCustomer(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "customer not found")
		return
	}
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) UpdateCustomer(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input customerInput
	if !bindJSON(c, &input) {
		return
	}
	input.Name = strings.TrimSpace(input.Name)
	if input.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "customer name is required"})
		return
	}

	var item customerPayload
	err := h.db.QueryRow(c.Request.Context(), `
		UPDATE customers
		SET name=$3, phone=$4, email=$5, address=$6, notes=$7, updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, name, COALESCE(phone, ''), COALESCE(email, ''), COALESCE(address, ''), COALESCE(notes, ''),
		          status, created_at, updated_at
	`, a.CompanyID, id, input.Name, input.Phone, input.Email, input.Address, input.Notes).Scan(
		&item.ID, &item.Name, newOptionalString(&item.Phone), newOptionalString(&item.Email),
		newOptionalString(&item.Address), newOptionalString(&item.Notes), &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "customer not found")
		return
	}
	writeAudit(h.db, c, a, "customers.update", "customer", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) DeleteCustomer(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}

	tag, err := h.db.Exec(c.Request.Context(), `
		UPDATE customers
		SET status='deleted', deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "customer not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "customer not found"})
		return
	}
	writeAudit(h.db, c, a, "customers.delete", "customer", id, nil)
	c.Status(http.StatusNoContent)
}

type projectPayload struct {
	ID           uuid.UUID `json:"id"`
	CustomerID   uuid.UUID `json:"customer_id"`
	CustomerName string    `json:"customer_name"`
	Title        string    `json:"title"`
	RoomType     string    `json:"room_type"`
	Status       string    `json:"status"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type projectInput struct {
	CustomerID uuid.UUID `json:"customer_id"`
	Title      string    `json:"title"`
	RoomType   string    `json:"room_type"`
	Status     string    `json:"status"`
}

func (h BusinessHandler) ListProjects(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}

	args := []any{a.CompanyID}
	query := `
		SELECT p.id, p.customer_id, c.name, p.title, p.room_type, p.status, p.created_at, p.updated_at
		FROM projects p
		JOIN customers c ON c.id=p.customer_id AND c.company_id=p.company_id AND c.deleted_at IS NULL
		WHERE p.company_id=$1 AND p.deleted_at IS NULL
	`
	if customerID := strings.TrimSpace(c.Query("customer_id")); customerID != "" {
		id, err := uuid.Parse(customerID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid customer_id"})
			return
		}
		args = append(args, id)
		query += ` AND p.customer_id=$2`
	}
	query += ` ORDER BY p.updated_at DESC, p.created_at DESC`

	rows, err := h.db.Query(c.Request.Context(), query, args...)
	if err != nil {
		writeDBError(c, err, "projects not found")
		return
	}
	defer rows.Close()

	items := make([]projectPayload, 0)
	for rows.Next() {
		item, err := scanProject(rows)
		if err != nil {
			writeDBError(c, err, "projects not found")
			return
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeDBError(c, err, "projects not found")
		return
	}
	c.JSON(http.StatusOK, listResponse[projectPayload]{Items: items})
}

func (h BusinessHandler) CreateProject(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	var input projectInput
	if !bindJSON(c, &input) {
		return
	}
	normalizeProjectInput(&input)
	if input.CustomerID == uuid.Nil || input.Title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "customer_id and title are required"})
		return
	}

	tx, err := h.db.Begin(c.Request.Context())
	if err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	defer tx.Rollback(c.Request.Context())

	var item projectPayload
	err = tx.QueryRow(c.Request.Context(), `
		INSERT INTO projects (company_id, customer_id, title, room_type, status, created_by)
		SELECT $1, c.id, $3, $4, $5, $6
		FROM customers c
		WHERE c.company_id=$1 AND c.id=$2 AND c.deleted_at IS NULL
		RETURNING id, customer_id, (SELECT name FROM customers WHERE id=$2), title, room_type, status, created_at, updated_at
	`, a.CompanyID, input.CustomerID, input.Title, input.RoomType, input.Status, a.UserID).Scan(
		&item.ID, &item.CustomerID, &item.CustomerName, &item.Title, &item.RoomType, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		if errorsIsNoRows(err) {
			c.JSON(http.StatusNotFound, gin.H{"error": "customer not found"})
			return
		}
		writeDBError(c, err, "project not found")
		return
	}
	if _, err := tx.Exec(c.Request.Context(), `
		INSERT INTO drawings (company_id, project_id, created_by)
		VALUES ($1, $2, $3)
		ON CONFLICT (company_id, project_id) DO NOTHING
	`, a.CompanyID, item.ID, a.UserID); err != nil {
		writeDBError(c, err, "drawing not found")
		return
	}
	if err := tx.Commit(c.Request.Context()); err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	writeAudit(h.db, c, a, "projects.create", "project", item.ID, gin.H{"title": item.Title})
	c.JSON(http.StatusCreated, item)
}

func (h BusinessHandler) GetProject(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	item, err := h.getProject(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) UpdateProject(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input projectInput
	if !bindJSON(c, &input) {
		return
	}
	normalizeProjectInput(&input)
	if input.CustomerID == uuid.Nil || input.Title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "customer_id and title are required"})
		return
	}

	var item projectPayload
	err := h.db.QueryRow(c.Request.Context(), `
		UPDATE projects p
		SET customer_id=c.id, title=$4, room_type=$5, status=$6, updated_at=now()
		FROM customers c
		WHERE p.company_id=$1 AND p.id=$2 AND p.deleted_at IS NULL
		  AND c.company_id=$1 AND c.id=$3 AND c.deleted_at IS NULL
		RETURNING p.id, p.customer_id, c.name, p.title, p.room_type, p.status, p.created_at, p.updated_at
	`, a.CompanyID, id, input.CustomerID, input.Title, input.RoomType, input.Status).Scan(
		&item.ID, &item.CustomerID, &item.CustomerName, &item.Title, &item.RoomType, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	writeAudit(h.db, c, a, "projects.update", "project", item.ID, gin.H{"title": item.Title})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) DeleteProject(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	tag, err := h.db.Exec(c.Request.Context(), `
		UPDATE projects
		SET status='deleted', deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
		return
	}
	writeAudit(h.db, c, a, "projects.delete", "project", id, nil)
	c.Status(http.StatusNoContent)
}

func (h BusinessHandler) getCustomer(c *gin.Context, companyID uuid.UUID, id uuid.UUID) (customerPayload, error) {
	var item customerPayload
	err := h.db.QueryRow(c.Request.Context(), `
		SELECT id, name, COALESCE(phone, ''), COALESCE(email, ''), COALESCE(address, ''), COALESCE(notes, ''),
		       status, created_at, updated_at
		FROM customers
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, companyID, id).Scan(
		&item.ID, &item.Name, newOptionalString(&item.Phone), newOptionalString(&item.Email),
		newOptionalString(&item.Address), newOptionalString(&item.Notes), &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, err
}

func (h BusinessHandler) getProject(c *gin.Context, companyID uuid.UUID, id uuid.UUID) (projectPayload, error) {
	var item projectPayload
	err := h.db.QueryRow(c.Request.Context(), `
		SELECT p.id, p.customer_id, c.name, p.title, p.room_type, p.status, p.created_at, p.updated_at
		FROM projects p
		JOIN customers c ON c.id=p.customer_id AND c.company_id=p.company_id AND c.deleted_at IS NULL
		WHERE p.company_id=$1 AND p.id=$2 AND p.deleted_at IS NULL
	`, companyID, id).Scan(
		&item.ID, &item.CustomerID, &item.CustomerName, &item.Title, &item.RoomType, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, err
}

func normalizeProjectInput(input *projectInput) {
	input.Title = strings.TrimSpace(input.Title)
	input.RoomType = strings.TrimSpace(input.RoomType)
	if input.RoomType == "" {
		input.RoomType = "bathroom"
	}
	input.Status = defaultStatus(input.Status, "draft")
}

type stringScanner struct {
	target **string
}

func newOptionalString(target **string) *stringScanner {
	return &stringScanner{target: target}
}

func (s *stringScanner) Scan(value any) error {
	if value == nil {
		*s.target = nil
		return nil
	}
	var text string
	switch v := value.(type) {
	case string:
		text = v
	case []byte:
		text = string(v)
	default:
		text = strings.TrimSpace(v.(string))
	}
	*s.target = optionalString(text)
	return nil
}

func scanCustomer(row pgx.Row) (customerPayload, error) {
	var item customerPayload
	err := row.Scan(
		&item.ID, &item.Name, newOptionalString(&item.Phone), newOptionalString(&item.Email),
		newOptionalString(&item.Address), newOptionalString(&item.Notes), &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, err
}

func scanProject(row pgx.Row) (projectPayload, error) {
	var item projectPayload
	err := row.Scan(
		&item.ID, &item.CustomerID, &item.CustomerName, &item.Title, &item.RoomType, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, err
}

func errorsIsNoRows(err error) bool {
	return err == pgx.ErrNoRows
}
