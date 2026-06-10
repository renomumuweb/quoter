package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"quoter/backend/internal/domain/catalog"
)

type estimateTemplatePayload struct {
	ID             uuid.UUID       `json:"id"`
	ProjectID      *uuid.UUID      `json:"project_id,omitempty"`
	Name           string          `json:"name"`
	RenovationType string          `json:"renovation_type"`
	Categories     json.RawMessage `json:"categories"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
}

type estimateTemplateInput struct {
	ProjectID      *uuid.UUID      `json:"project_id"`
	Name           string          `json:"name"`
	RenovationType string          `json:"renovation_type"`
	Categories     json.RawMessage `json:"categories"`
}

type estimateTemplateCategoryJSON struct {
	ID        uuid.UUID                  `json:"id"`
	Name      string                     `json:"name"`
	Items     []estimateTemplateItemJSON `json:"items"`
	SortOrder int                        `json:"sort_order"`
}

type estimateTemplateItemJSON struct {
	ID                      uuid.UUID                     `json:"id"`
	ProductID               *uuid.UUID                    `json:"product_id,omitempty"`
	ProductNameSnapshot     *string                       `json:"product_name_snapshot,omitempty"`
	SKUSnapshot             *string                       `json:"sku_snapshot,omitempty"`
	BrandSnapshot           *string                       `json:"brand_snapshot,omitempty"`
	ProductCategorySnapshot *string                       `json:"product_category_snapshot,omitempty"`
	MaterialSnapshot        *string                       `json:"material_snapshot,omitempty"`
	UnitPriceSnapshot       *float64                      `json:"unit_price_snapshot,omitempty"`
	ItemName                string                        `json:"item_name"`
	CategoryID              uuid.UUID                     `json:"category_id"`
	RoomName                string                        `json:"room_name"`
	RoomType                string                        `json:"room_type"`
	FloorLevel              string                        `json:"floor_level"`
	ScopeCode               string                        `json:"scope_code"`
	MaterialChoice          string                        `json:"material_choice"`
	SuppliedBy              string                        `json:"supplied_by"`
	RiskFlags               []string                      `json:"risk_flags"`
	PricingStatus           string                        `json:"pricing_status"`
	Description             string                        `json:"description"`
	Quantity                float64                       `json:"quantity"`
	Unit                    string                        `json:"unit"`
	Costs                   estimateTemplateCostBreakdown `json:"costs"`
	Notes                   string                        `json:"notes"`
	Selected                bool                          `json:"selected"`
}

type estimateTemplateCostBreakdown struct {
	MaterialCost      float64 `json:"material_cost"`
	LaborCost         float64 `json:"labor_cost"`
	SubcontractorCost float64 `json:"subcontractor_cost"`
	OtherCost         float64 `json:"other_cost"`
	Markup            float64 `json:"markup"`
	Tax               float64 `json:"tax"`
}

func (h BusinessHandler) ListEstimateTemplates(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}

	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id, COALESCE(source_project_id::text, ''), name, renovation_type, categories, created_at, updated_at
		FROM estimate_templates
		WHERE company_id=$1 AND deleted_at IS NULL
		ORDER BY updated_at DESC, created_at DESC
	`, a.CompanyID)
	if err != nil {
		writeDBError(c, err, "estimate templates not found")
		return
	}
	defer rows.Close()

	items := make([]estimateTemplatePayload, 0)
	for rows.Next() {
		var item estimateTemplatePayload
		var projectIDText string
		if err := rows.Scan(
			&item.ID,
			&projectIDText,
			&item.Name,
			&item.RenovationType,
			&item.Categories,
			&item.CreatedAt,
			&item.UpdatedAt,
		); err != nil {
			writeDBError(c, err, "estimate templates not found")
			return
		}
		item.ProjectID = optionalUUID(projectIDText)
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeDBError(c, err, "estimate templates not found")
		return
	}

	c.JSON(http.StatusOK, listResponse[estimateTemplatePayload]{Items: items})
}

func (h BusinessHandler) CreateEstimateTemplate(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}

	var input estimateTemplateInput
	if !bindJSON(c, &input) {
		return
	}
	if !h.normalizeEstimateTemplateInput(c, a.CompanyID, &input) {
		return
	}
	if input.ProjectID != nil && !h.projectBelongsToCompany(c, a.CompanyID, *input.ProjectID) {
		c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
		return
	}

	tx, err := h.db.Begin(c.Request.Context())
	if err != nil {
		writeDBError(c, err, "estimate template not found")
		return
	}
	defer tx.Rollback(c.Request.Context())

	var existingID uuid.UUID
	err = tx.QueryRow(c.Request.Context(), `
		SELECT id
		FROM estimate_templates
		WHERE company_id=$1 AND lower(name)=lower($2) AND deleted_at IS NULL
	`, a.CompanyID, input.Name).Scan(&existingID)

	var item estimateTemplatePayload
	if err == nil {
		item, err = updateEstimateTemplateRow(c, tx, a.CompanyID, existingID, input)
		if err != nil {
			writeDBError(c, err, "estimate template not found")
			return
		}
		if err := tx.Commit(c.Request.Context()); err != nil {
			writeDBError(c, err, "estimate template not found")
			return
		}
		writeAudit(h.db, c, a, "estimate_templates.update", "estimate_template", item.ID, gin.H{"name": item.Name})
		c.JSON(http.StatusOK, item)
		return
	}
	if !errorsIsNoRows(err) {
		writeDBError(c, err, "estimate template not found")
		return
	}

	var projectIDText string
	err = tx.QueryRow(c.Request.Context(), `
		INSERT INTO estimate_templates (company_id, source_project_id, name, renovation_type, categories, created_by)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, COALESCE(source_project_id::text, ''), name, renovation_type, categories, created_at, updated_at
	`, a.CompanyID, input.ProjectID, input.Name, input.RenovationType, input.Categories, a.UserID).Scan(
		&item.ID,
		&projectIDText,
		&item.Name,
		&item.RenovationType,
		&item.Categories,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "estimate template not found")
		return
	}
	if err := tx.Commit(c.Request.Context()); err != nil {
		writeDBError(c, err, "estimate template not found")
		return
	}
	item.ProjectID = optionalUUID(projectIDText)
	writeAudit(h.db, c, a, "estimate_templates.create", "estimate_template", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusCreated, item)
}

func (h BusinessHandler) GetEstimateTemplate(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	item, err := h.getEstimateTemplate(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "estimate template not found")
		return
	}
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) UpdateEstimateTemplate(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input estimateTemplateInput
	if !bindJSON(c, &input) {
		return
	}
	if !h.normalizeEstimateTemplateInput(c, a.CompanyID, &input) {
		return
	}
	if input.ProjectID != nil && !h.projectBelongsToCompany(c, a.CompanyID, *input.ProjectID) {
		c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
		return
	}

	tx, err := h.db.Begin(c.Request.Context())
	if err != nil {
		writeDBError(c, err, "estimate template not found")
		return
	}
	defer tx.Rollback(c.Request.Context())

	item, err := updateEstimateTemplateRow(c, tx, a.CompanyID, id, input)
	if err != nil {
		writeDBError(c, err, "estimate template not found")
		return
	}
	if err := tx.Commit(c.Request.Context()); err != nil {
		writeDBError(c, err, "estimate template not found")
		return
	}
	writeAudit(h.db, c, a, "estimate_templates.update", "estimate_template", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) DeleteEstimateTemplate(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	tag, err := h.db.Exec(c.Request.Context(), `
		UPDATE estimate_templates
		SET active=false, deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "estimate template not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "estimate template not found"})
		return
	}
	writeAudit(h.db, c, a, "estimate_templates.delete", "estimate_template", id, nil)
	c.Status(http.StatusNoContent)
}

func (h BusinessHandler) normalizeEstimateTemplateInput(c *gin.Context, companyID uuid.UUID, input *estimateTemplateInput) bool {
	input.Name = strings.TrimSpace(input.Name)
	input.RenovationType = strings.TrimSpace(input.RenovationType)
	if input.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "template name is required"})
		return false
	}
	if input.RenovationType == "" {
		input.RenovationType = "custom_project"
	}
	if len(input.Categories) == 0 {
		input.Categories = json.RawMessage(`[]`)
	}
	if !json.Valid(input.Categories) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "categories must be valid JSON"})
		return false
	}
	enriched, err := h.enrichEstimateTemplateCategories(c, companyID, input.Categories)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return false
	}
	input.Categories = enriched
	return true
}

func (h BusinessHandler) enrichEstimateTemplateCategories(c *gin.Context, companyID uuid.UUID, raw json.RawMessage) (json.RawMessage, error) {
	var categories []estimateTemplateCategoryJSON
	if err := json.Unmarshal(raw, &categories); err != nil {
		return nil, err
	}

	productCache := map[uuid.UUID]catalog.Product{}
	for categoryIndex := range categories {
		categories[categoryIndex].Name = strings.TrimSpace(categories[categoryIndex].Name)
		for itemIndex := range categories[categoryIndex].Items {
			item := &categories[categoryIndex].Items[itemIndex]
			item.ItemName = strings.TrimSpace(item.ItemName)
			item.Description = strings.TrimSpace(item.Description)
			item.RoomName = strings.TrimSpace(item.RoomName)
			item.RoomType = strings.TrimSpace(item.RoomType)
			item.FloorLevel = strings.TrimSpace(item.FloorLevel)
			item.ScopeCode = strings.TrimSpace(item.ScopeCode)
			item.MaterialChoice = strings.TrimSpace(item.MaterialChoice)
			item.SuppliedBy = strings.TrimSpace(item.SuppliedBy)
			item.PricingStatus = strings.TrimSpace(item.PricingStatus)
			if item.PricingStatus == "" {
				item.PricingStatus = "pending"
			}
			item.Unit = strings.TrimSpace(item.Unit)
			item.Notes = strings.TrimSpace(item.Notes)
			if item.Quantity <= 0 {
				item.Quantity = 1
			}
			if item.ProductID == nil {
				continue
			}

			product, ok := productCache[*item.ProductID]
			if !ok {
				loaded, err := h.catalog.GetProduct(c.Request.Context(), companyID, *item.ProductID)
				if err != nil {
					return nil, catalog.ValidationError{Message: "linked product not found in this company catalog"}
				}
				product = loaded
				productCache[*item.ProductID] = loaded
			}
			enrichEstimateTemplateItemFromProduct(item, product)
		}
	}

	enriched, err := json.Marshal(categories)
	if err != nil {
		return nil, err
	}
	return enriched, nil
}

func enrichEstimateTemplateItemFromProduct(item *estimateTemplateItemJSON, product catalog.Product) {
	item.ProductNameSnapshot = stringValue(product.Name)
	item.SKUSnapshot = stringValue(product.SKU)
	item.BrandSnapshot = optionalString(product.Brand)
	item.ProductCategorySnapshot = stringValue(product.Category)
	item.MaterialSnapshot = product.Material
	item.UnitPriceSnapshot = nil

	if item.ItemName == "" {
		item.ItemName = product.Name
	}
	if item.Description == "" && product.Description != nil {
		item.Description = *product.Description
	}
	if item.Unit == "" {
		item.Unit = product.Unit
	}
}

func stringValue(value string) *string {
	return optionalString(value)
}

func (h BusinessHandler) getEstimateTemplate(c *gin.Context, companyID uuid.UUID, id uuid.UUID) (estimateTemplatePayload, error) {
	var item estimateTemplatePayload
	var projectIDText string
	err := h.db.QueryRow(c.Request.Context(), `
		SELECT id, COALESCE(source_project_id::text, ''), name, renovation_type, categories, created_at, updated_at
		FROM estimate_templates
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, companyID, id).Scan(
		&item.ID,
		&projectIDText,
		&item.Name,
		&item.RenovationType,
		&item.Categories,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	item.ProjectID = optionalUUID(projectIDText)
	return item, err
}

func (h BusinessHandler) projectBelongsToCompany(c *gin.Context, companyID uuid.UUID, projectID uuid.UUID) bool {
	var exists bool
	if err := h.db.QueryRow(c.Request.Context(), `
		SELECT EXISTS (
			SELECT 1
			FROM projects
			WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
		)
	`, companyID, projectID).Scan(&exists); err != nil {
		return false
	}
	return exists
}

func updateEstimateTemplateRow(
	c *gin.Context,
	tx pgx.Tx,
	companyID uuid.UUID,
	id uuid.UUID,
	input estimateTemplateInput,
) (estimateTemplatePayload, error) {
	var item estimateTemplatePayload
	var projectIDText string
	err := tx.QueryRow(c.Request.Context(), `
		UPDATE estimate_templates
		SET source_project_id=$3, name=$4, renovation_type=$5, categories=$6, updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, COALESCE(source_project_id::text, ''), name, renovation_type, categories, created_at, updated_at
	`, companyID, id, input.ProjectID, input.Name, input.RenovationType, input.Categories).Scan(
		&item.ID,
		&projectIDText,
		&item.Name,
		&item.RenovationType,
		&item.Categories,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	item.ProjectID = optionalUUID(projectIDText)
	return item, err
}
