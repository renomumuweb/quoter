package handlers

import (
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type brandPayload struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type brandInput struct {
	Name string `json:"name"`
}

type productCategoryPayload struct {
	ID        uuid.UUID  `json:"id"`
	ParentID  *uuid.UUID `json:"parent_id,omitempty"`
	Name      string     `json:"name"`
	Kind      string     `json:"kind"`
	Status    string     `json:"status"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
}

type productCategoryInput struct {
	ParentID *uuid.UUID `json:"parent_id"`
	Name     string     `json:"name"`
	Kind     string     `json:"kind"`
}

type productPayload struct {
	ID             uuid.UUID  `json:"id"`
	BrandID        *uuid.UUID `json:"brand_id,omitempty"`
	Brand          string     `json:"brand"`
	CategoryID     uuid.UUID  `json:"category_id"`
	Category       string     `json:"category"`
	CategoryKind   string     `json:"category_kind"`
	Name           string     `json:"name"`
	SKU            string     `json:"sku"`
	Size           *string    `json:"size,omitempty"`
	Color          *string    `json:"color,omitempty"`
	Material       *string    `json:"material,omitempty"`
	Unit           string     `json:"unit"`
	Description    *string    `json:"description,omitempty"`
	ImageURL       *string    `json:"image_url,omitempty"`
	Active         bool       `json:"active"`
	IsService      bool       `json:"is_service"`
	Status         string     `json:"status"`
	CurrentPriceID *uuid.UUID `json:"current_price_id,omitempty"`
	Currency       string     `json:"currency"`
	CurrentPrice   *float64   `json:"current_price,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

type productInput struct {
	BrandID      *uuid.UUID `json:"brand_id"`
	CategoryID   uuid.UUID  `json:"category_id"`
	Name         string     `json:"name"`
	SKU          string     `json:"sku"`
	Size         *string    `json:"size"`
	Color        *string    `json:"color"`
	Material     *string    `json:"material"`
	Unit         string     `json:"unit"`
	Description  *string    `json:"description"`
	ImageURL     *string    `json:"image_url"`
	Active       *bool      `json:"active"`
	IsService    *bool      `json:"is_service"`
	CurrentPrice *float64   `json:"current_price"`
	Currency     string     `json:"currency"`
}

func (h BusinessHandler) ListBrands(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id, name, status, created_at, updated_at
		FROM brands
		WHERE company_id=$1 AND deleted_at IS NULL
		ORDER BY name ASC
	`, a.CompanyID)
	if err != nil {
		writeDBError(c, err, "brands not found")
		return
	}
	defer rows.Close()
	items := make([]brandPayload, 0)
	for rows.Next() {
		var item brandPayload
		if err := rows.Scan(&item.ID, &item.Name, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			writeDBError(c, err, "brands not found")
			return
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeDBError(c, err, "brands not found")
		return
	}
	c.JSON(http.StatusOK, listResponse[brandPayload]{Items: items})
}

func (h BusinessHandler) CreateBrand(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	var input brandInput
	if !bindJSON(c, &input) {
		return
	}
	input.Name = strings.TrimSpace(input.Name)
	if input.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "brand name is required"})
		return
	}
	var item brandPayload
	err := h.db.QueryRow(c.Request.Context(), `
		INSERT INTO brands (company_id, name)
		VALUES ($1, $2)
		RETURNING id, name, status, created_at, updated_at
	`, a.CompanyID, input.Name).Scan(&item.ID, &item.Name, &item.Status, &item.CreatedAt, &item.UpdatedAt)
	if err != nil {
		writeDBError(c, err, "brand not found")
		return
	}
	writeAudit(h.db, c, a, "brands.create", "brand", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusCreated, item)
}

func (h BusinessHandler) UpdateBrand(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input brandInput
	if !bindJSON(c, &input) {
		return
	}
	input.Name = strings.TrimSpace(input.Name)
	if input.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "brand name is required"})
		return
	}
	var item brandPayload
	err := h.db.QueryRow(c.Request.Context(), `
		UPDATE brands
		SET name=$3, updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, name, status, created_at, updated_at
	`, a.CompanyID, id, input.Name).Scan(&item.ID, &item.Name, &item.Status, &item.CreatedAt, &item.UpdatedAt)
	if err != nil {
		writeDBError(c, err, "brand not found")
		return
	}
	writeAudit(h.db, c, a, "brands.update", "brand", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) DeleteBrand(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	tag, err := h.db.Exec(c.Request.Context(), `
		UPDATE brands
		SET status='deleted', deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "brand not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "brand not found"})
		return
	}
	writeAudit(h.db, c, a, "brands.delete", "brand", id, nil)
	c.Status(http.StatusNoContent)
}

func (h BusinessHandler) ListProductCategories(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id, COALESCE(parent_id::text, ''), name, kind, status, created_at, updated_at
		FROM product_categories
		WHERE company_id=$1 AND deleted_at IS NULL
		ORDER BY kind ASC, name ASC
	`, a.CompanyID)
	if err != nil {
		writeDBError(c, err, "product categories not found")
		return
	}
	defer rows.Close()
	items := make([]productCategoryPayload, 0)
	for rows.Next() {
		var item productCategoryPayload
		if err := rows.Scan(&item.ID, uuidTextScanner(&item.ParentID), &item.Name, &item.Kind, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			writeDBError(c, err, "product categories not found")
			return
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeDBError(c, err, "product categories not found")
		return
	}
	c.JSON(http.StatusOK, listResponse[productCategoryPayload]{Items: items})
}

func (h BusinessHandler) CreateProductCategory(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	var input productCategoryInput
	if !bindJSON(c, &input) || !normalizeProductCategoryInput(c, &input) {
		return
	}
	var item productCategoryPayload
	err := h.db.QueryRow(c.Request.Context(), `
		INSERT INTO product_categories (company_id, parent_id, name, kind)
		VALUES (
			$1,
			(CASE WHEN $2::uuid IS NULL THEN NULL ELSE (SELECT id FROM product_categories WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL) END),
			$3, $4
		)
		RETURNING id, COALESCE(parent_id::text, ''), name, kind, status, created_at, updated_at
	`, a.CompanyID, input.ParentID, input.Name, input.Kind).Scan(
		&item.ID, uuidTextScanner(&item.ParentID), &item.Name, &item.Kind, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "product category not found")
		return
	}
	writeAudit(h.db, c, a, "product_categories.create", "product_category", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusCreated, item)
}

func (h BusinessHandler) UpdateProductCategory(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input productCategoryInput
	if !bindJSON(c, &input) || !normalizeProductCategoryInput(c, &input) {
		return
	}
	var item productCategoryPayload
	err := h.db.QueryRow(c.Request.Context(), `
		UPDATE product_categories
		SET parent_id=(CASE WHEN $3::uuid IS NULL THEN NULL ELSE (SELECT id FROM product_categories WHERE company_id=$1 AND id=$3 AND deleted_at IS NULL) END),
		    name=$4, kind=$5, updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, COALESCE(parent_id::text, ''), name, kind, status, created_at, updated_at
	`, a.CompanyID, id, input.ParentID, input.Name, input.Kind).Scan(
		&item.ID, uuidTextScanner(&item.ParentID), &item.Name, &item.Kind, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "product category not found")
		return
	}
	writeAudit(h.db, c, a, "product_categories.update", "product_category", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) DeleteProductCategory(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	tag, err := h.db.Exec(c.Request.Context(), `
		UPDATE product_categories
		SET status='deleted', deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "product category not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "product category not found"})
		return
	}
	writeAudit(h.db, c, a, "product_categories.delete", "product_category", id, nil)
	c.Status(http.StatusNoContent)
}

func (h BusinessHandler) ListProducts(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	items, err := h.queryProducts(c, a.CompanyID, productFilter{
		Query:      c.Query("q"),
		CategoryID: c.Query("category_id"),
		BrandID:    c.Query("brand_id"),
		ActiveOnly: c.DefaultQuery("active", "true") != "false",
	})
	if err != nil {
		writeDBError(c, err, "products not found")
		return
	}
	c.JSON(http.StatusOK, listResponse[productPayload]{Items: items})
}

func (h BusinessHandler) CreateProduct(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	var input productInput
	if !bindJSON(c, &input) || !normalizeProductInput(c, &input) {
		return
	}
	tx, err := h.db.Begin(c.Request.Context())
	if err != nil {
		writeDBError(c, err, "product not found")
		return
	}
	defer tx.Rollback(c.Request.Context())

	var id uuid.UUID
	err = tx.QueryRow(c.Request.Context(), `
		INSERT INTO products (
			company_id, brand_id, category_id, name, sku, size, color, material, unit,
			description, image_url, active, is_service
		)
		SELECT $1,
		       (CASE WHEN $2::uuid IS NULL THEN NULL ELSE (SELECT id FROM brands WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL) END),
		       c.id, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
		FROM product_categories c
		WHERE c.company_id=$1 AND c.id=$3 AND c.deleted_at IS NULL
		RETURNING id
	`, a.CompanyID, input.BrandID, input.CategoryID, input.Name, input.SKU, input.Size, input.Color,
		input.Material, input.Unit, input.Description, input.ImageURL, activeValue(input.Active), isServiceValue(input.IsService)).Scan(&id)
	if err != nil {
		writeDBError(c, err, "product category not found")
		return
	}
	if input.CurrentPrice != nil {
		if _, err := tx.Exec(c.Request.Context(), `
			INSERT INTO product_prices (company_id, product_id, currency, unit_price, effective_from)
			VALUES ($1, $2, $3, $4, CURRENT_DATE)
			ON CONFLICT (product_id, effective_from)
			DO UPDATE SET unit_price=EXCLUDED.unit_price, currency=EXCLUDED.currency
		`, a.CompanyID, id, input.Currency, *input.CurrentPrice); err != nil {
			writeDBError(c, err, "product price not found")
			return
		}
	}
	if err := tx.Commit(c.Request.Context()); err != nil {
		writeDBError(c, err, "product not found")
		return
	}
	item, err := h.getProductPayload(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "product not found")
		return
	}
	writeAudit(h.db, c, a, "products.create", "product", item.ID, gin.H{"sku": item.SKU})
	c.JSON(http.StatusCreated, item)
}

func (h BusinessHandler) GetProduct(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	item, err := h.getProductPayload(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "product not found")
		return
	}
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) UpdateProduct(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input productInput
	if !bindJSON(c, &input) || !normalizeProductInput(c, &input) {
		return
	}
	tx, err := h.db.Begin(c.Request.Context())
	if err != nil {
		writeDBError(c, err, "product not found")
		return
	}
	defer tx.Rollback(c.Request.Context())

	tag, err := tx.Exec(c.Request.Context(), `
		UPDATE products p
		SET brand_id=(CASE WHEN $3::uuid IS NULL THEN NULL ELSE (SELECT id FROM brands WHERE company_id=$1 AND id=$3 AND deleted_at IS NULL) END),
		    category_id=c.id, name=$5, sku=$6, size=$7, color=$8, material=$9, unit=$10,
		    description=$11, image_url=$12, active=$13, is_service=$14, updated_at=now()
		FROM product_categories c
		WHERE p.company_id=$1 AND p.id=$2 AND p.deleted_at IS NULL
		  AND c.company_id=$1 AND c.id=$4 AND c.deleted_at IS NULL
	`, a.CompanyID, id, input.BrandID, input.CategoryID, input.Name, input.SKU, input.Size,
		input.Color, input.Material, input.Unit, input.Description, input.ImageURL, activeValue(input.Active), isServiceValue(input.IsService))
	if err != nil {
		writeDBError(c, err, "product not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found"})
		return
	}
	if input.CurrentPrice != nil {
		if _, err := tx.Exec(c.Request.Context(), `
			INSERT INTO product_prices (company_id, product_id, currency, unit_price, effective_from)
			VALUES ($1, $2, $3, $4, CURRENT_DATE)
			ON CONFLICT (product_id, effective_from)
			DO UPDATE SET unit_price=EXCLUDED.unit_price, currency=EXCLUDED.currency
		`, a.CompanyID, id, input.Currency, *input.CurrentPrice); err != nil {
			writeDBError(c, err, "product price not found")
			return
		}
	}
	if err := tx.Commit(c.Request.Context()); err != nil {
		writeDBError(c, err, "product not found")
		return
	}
	item, err := h.getProductPayload(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "product not found")
		return
	}
	writeAudit(h.db, c, a, "products.update", "product", item.ID, gin.H{"sku": item.SKU})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) DeleteProduct(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	tag, err := h.db.Exec(c.Request.Context(), `
		UPDATE products
		SET status='deleted', active=false, deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "product not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found"})
		return
	}
	writeAudit(h.db, c, a, "products.delete", "product", id, nil)
	c.Status(http.StatusNoContent)
}

type productMatchPayload struct {
	Product         productPayload `json:"product"`
	Score           float64        `json:"score"`
	Reasons         []string       `json:"reasons"`
	MatchedKeywords []string       `json:"matched_keywords"`
	MatchedSize     *string        `json:"matched_size,omitempty"`
	MatchedColor    *string        `json:"matched_color,omitempty"`
	MatchedCategory *string        `json:"matched_category,omitempty"`
}

func (h BusinessHandler) RecommendProducts(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	objectType := strings.ToLower(strings.TrimSpace(c.Query("object_type")))
	annotation := strings.ToLower(strings.TrimSpace(c.Query("annotation")))
	roomType := strings.ToLower(strings.TrimSpace(c.DefaultQuery("room_type", "bathroom")))
	products, err := h.queryProducts(c, a.CompanyID, productFilter{ActiveOnly: true})
	if err != nil {
		writeDBError(c, err, "products not found")
		return
	}
	results := make([]productMatchPayload, 0)
	for _, product := range products {
		score, reasons, keywords, size, color, category := scoreProductMatch(product, objectType, annotation, roomType)
		if score <= 0 {
			continue
		}
		results = append(results, productMatchPayload{
			Product: product, Score: roundMoney(score), Reasons: reasons, MatchedKeywords: keywords,
			MatchedSize: size, MatchedColor: color, MatchedCategory: category,
		})
	}
	sort.Slice(results, func(i, j int) bool { return results[i].Score > results[j].Score })
	if len(results) > 12 {
		results = results[:12]
	}
	c.JSON(http.StatusOK, listResponse[productMatchPayload]{Items: results})
}

type productFilter struct {
	Query      string
	CategoryID string
	BrandID    string
	ActiveOnly bool
}

func (h BusinessHandler) queryProducts(c *gin.Context, companyID uuid.UUID, filter productFilter) ([]productPayload, error) {
	args := []any{companyID}
	query := `
		SELECT p.id, COALESCE(p.brand_id::text, ''), COALESCE(b.name, ''), p.category_id, pc.name, pc.kind,
		       p.name, p.sku, COALESCE(p.size, ''), COALESCE(p.color, ''), COALESCE(p.material, ''), p.unit,
		       COALESCE(p.description, ''), COALESCE(p.image_url, ''), p.active, p.is_service, p.status, p.created_at, p.updated_at,
		       COALESCE(price.id::text, ''), COALESCE(price.currency, 'USD'), COALESCE(price.unit_price::text, '')
		FROM products p
		JOIN product_categories pc ON pc.id=p.category_id AND pc.company_id=p.company_id AND pc.deleted_at IS NULL
		LEFT JOIN brands b ON b.id=p.brand_id AND b.company_id=p.company_id AND b.deleted_at IS NULL
		LEFT JOIN LATERAL (
			SELECT id, currency, unit_price
			FROM product_prices
			WHERE company_id=p.company_id AND product_id=p.id
			  AND effective_from <= CURRENT_DATE
			  AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
			ORDER BY effective_from DESC
			LIMIT 1
		) price ON true
		WHERE p.company_id=$1 AND p.deleted_at IS NULL
	`
	if filter.ActiveOnly {
		query += ` AND p.active=true`
	}
	if strings.TrimSpace(filter.Query) != "" {
		args = append(args, "%"+strings.ToLower(strings.TrimSpace(filter.Query))+"%")
		query += ` AND (lower(p.name) LIKE $` + itoa(len(args)) + ` OR lower(p.sku) LIKE $` + itoa(len(args)) + ` OR lower(COALESCE(b.name, '')) LIKE $` + itoa(len(args)) + ` OR lower(pc.name) LIKE $` + itoa(len(args)) + `)`
	}
	if strings.TrimSpace(filter.CategoryID) != "" {
		if id, err := uuid.Parse(filter.CategoryID); err == nil {
			args = append(args, id)
			query += ` AND p.category_id=$` + itoa(len(args))
		}
	}
	if strings.TrimSpace(filter.BrandID) != "" {
		if id, err := uuid.Parse(filter.BrandID); err == nil {
			args = append(args, id)
			query += ` AND p.brand_id=$` + itoa(len(args))
		}
	}
	query += ` ORDER BY pc.name ASC, p.name ASC`

	rows, err := h.db.Query(c.Request.Context(), query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]productPayload, 0)
	for rows.Next() {
		item, err := scanProduct(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (h BusinessHandler) getProductPayload(c *gin.Context, companyID uuid.UUID, id uuid.UUID) (productPayload, error) {
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT p.id, COALESCE(p.brand_id::text, ''), COALESCE(b.name, ''), p.category_id, pc.name, pc.kind,
		       p.name, p.sku, COALESCE(p.size, ''), COALESCE(p.color, ''), COALESCE(p.material, ''), p.unit,
		       COALESCE(p.description, ''), COALESCE(p.image_url, ''), p.active, p.is_service, p.status, p.created_at, p.updated_at,
		       COALESCE(price.id::text, ''), COALESCE(price.currency, 'USD'), COALESCE(price.unit_price::text, '')
		FROM products p
		JOIN product_categories pc ON pc.id=p.category_id AND pc.company_id=p.company_id AND pc.deleted_at IS NULL
		LEFT JOIN brands b ON b.id=p.brand_id AND b.company_id=p.company_id AND b.deleted_at IS NULL
		LEFT JOIN LATERAL (
			SELECT id, currency, unit_price
			FROM product_prices
			WHERE company_id=p.company_id AND product_id=p.id
			  AND effective_from <= CURRENT_DATE
			  AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
			ORDER BY effective_from DESC
			LIMIT 1
		) price ON true
		WHERE p.company_id=$1 AND p.id=$2 AND p.deleted_at IS NULL
	`, companyID, id)
	if err != nil {
		return productPayload{}, err
	}
	defer rows.Close()
	if !rows.Next() {
		return productPayload{}, pgx.ErrNoRows
	}
	item, err := scanProduct(rows)
	if err != nil {
		return productPayload{}, err
	}
	return item, rows.Err()
}

func scanProduct(row interface{ Scan(...any) error }) (productPayload, error) {
	var item productPayload
	var priceText string
	err := row.Scan(
		&item.ID, uuidTextScanner(&item.BrandID), &item.Brand, &item.CategoryID, &item.Category, &item.CategoryKind,
		&item.Name, &item.SKU, newOptionalString(&item.Size), newOptionalString(&item.Color), newOptionalString(&item.Material), &item.Unit,
		newOptionalString(&item.Description), newOptionalString(&item.ImageURL), &item.Active, &item.IsService, &item.Status,
		&item.CreatedAt, &item.UpdatedAt, uuidTextScanner(&item.CurrentPriceID), &item.Currency, &priceText,
	)
	if price, ok := parseNumericString(priceText); ok {
		item.CurrentPrice = &price
	}
	return item, err
}

func normalizeProductCategoryInput(c *gin.Context, input *productCategoryInput) bool {
	input.Name = strings.TrimSpace(input.Name)
	input.Kind = strings.ToLower(strings.TrimSpace(input.Kind))
	if input.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "category name is required"})
		return false
	}
	if input.Kind == "" {
		input.Kind = "product"
	}
	if input.Kind != "product" && input.Kind != "service" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "category kind must be product or service"})
		return false
	}
	return true
}

func normalizeProductInput(c *gin.Context, input *productInput) bool {
	input.Name = strings.TrimSpace(input.Name)
	input.SKU = strings.TrimSpace(input.SKU)
	input.Unit = strings.TrimSpace(input.Unit)
	input.Currency = strings.TrimSpace(input.Currency)
	if input.Name == "" || input.SKU == "" || input.CategoryID == uuid.Nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "category_id, name, and sku are required"})
		return false
	}
	if input.Unit == "" {
		input.Unit = "each"
	}
	if input.Currency == "" {
		input.Currency = "USD"
	}
	trimStringPtr(&input.Size)
	trimStringPtr(&input.Color)
	trimStringPtr(&input.Material)
	trimStringPtr(&input.Description)
	trimStringPtr(&input.ImageURL)
	if input.CurrentPrice != nil && *input.CurrentPrice < 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "current_price must be zero or greater"})
		return false
	}
	return true
}

func trimStringPtr(value **string) {
	if value == nil || *value == nil {
		return
	}
	trimmed := strings.TrimSpace(**value)
	if trimmed == "" {
		*value = nil
		return
	}
	*value = &trimmed
}

func activeValue(value *bool) bool {
	if value == nil {
		return true
	}
	return *value
}

func isServiceValue(value *bool) bool {
	if value == nil {
		return false
	}
	return *value
}

func scoreProductMatch(product productPayload, objectType string, annotation string, roomType string) (float64, []string, []string, *string, *string, *string) {
	score := 0.0
	reasons := make([]string, 0)
	keywords := make([]string, 0)
	categoryLower := strings.ToLower(product.Category)
	if objectType != "" && (strings.Contains(categoryLower, objectType) || strings.Contains(objectType, categoryLower)) {
		score += 0.35
		reasons = append(reasons, "object_type matches product category")
		category := product.Category
		returnedKeywords := keywordMatches(product, annotation)
		keywords = append(keywords, returnedKeywords...)
		return scoreProductDetails(product, annotation, roomType, score, reasons, keywords, nil, nil, &category)
	}
	return scoreProductDetails(product, annotation, roomType, score, reasons, keywords, nil, nil, nil)
}

func scoreProductDetails(product productPayload, annotation string, roomType string, score float64, reasons []string, keywords []string, matchedSize *string, matchedColor *string, matchedCategory *string) (float64, []string, []string, *string, *string, *string) {
	matches := keywordMatches(product, annotation)
	if len(matches) > 0 {
		score += float64(len(matches)) * 0.04
		if score > 0.2 {
			score = 0.2 + (score - 0.2)
		}
		reasons = append(reasons, "annotation keywords match product fields")
		keywords = append(keywords, matches...)
	}
	for _, size := range []string{"60 inch", "60\"", "5 ft", "12 x 24", "24 x 48"} {
		if strings.Contains(annotation, size) && product.Size != nil && strings.Contains(strings.ToLower(*product.Size), strings.ReplaceAll(size, "\"", " inch")) {
			score += 0.2
			matchedSize = &size
			reasons = append(reasons, "annotation size matches product size")
			break
		}
	}
	for _, color := range []string{"matte black", "brushed nickel", "white", "black", "chrome"} {
		if strings.Contains(annotation, color) && product.Color != nil && strings.Contains(strings.ToLower(*product.Color), color) {
			score += 0.15
			matchedColor = &color
			reasons = append(reasons, "annotation color matches product color")
			break
		}
	}
	if strings.Contains(roomType, "bath") && containsAny(strings.ToLower(product.Category), []string{"vanity", "toilet", "shower", "tile", "install"}) {
		score += 0.08
		reasons = append(reasons, "bathroom project boosts common bath category")
	}
	if product.CurrentPrice != nil {
		score += 0.08
		reasons = append(reasons, "product has an active price")
	}
	if !product.Active {
		score -= 0.2
	}
	if score > 1 {
		score = 1
	}
	return score, reasons, uniqueStrings(keywords), matchedSize, matchedColor, matchedCategory
}

func keywordMatches(product productPayload, annotation string) []string {
	if annotation == "" {
		return nil
	}
	haystack := strings.ToLower(strings.Join([]string{
		product.Name, product.SKU, product.Brand, product.Category, optionalValue(product.Size), optionalValue(product.Color),
	}, " "))
	matches := make([]string, 0)
	for _, token := range strings.Fields(annotation) {
		token = strings.Trim(token, ",.;:()[]")
		if len(token) >= 3 && strings.Contains(haystack, token) {
			matches = append(matches, token)
		}
	}
	return uniqueStrings(matches)
}

func optionalValue(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func containsAny(value string, needles []string) bool {
	for _, needle := range needles {
		if strings.Contains(value, needle) {
			return true
		}
	}
	return false
}

func uniqueStrings(values []string) []string {
	seen := map[string]struct{}{}
	out := make([]string, 0, len(values))
	for _, value := range values {
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		out = append(out, value)
	}
	sort.Strings(out)
	return out
}

func itoa(value int) string {
	return strconv.Itoa(value)
}
