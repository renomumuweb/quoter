package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type projectEstimatePayload struct {
	ID             uuid.UUID       `json:"id"`
	ProjectID      uuid.UUID       `json:"project_id"`
	Name           string          `json:"name"`
	RenovationType string          `json:"renovation_type"`
	Categories     json.RawMessage `json:"categories"`
	Status         string          `json:"status"`
	Version        int             `json:"version"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
}

type projectEstimateInput struct {
	RenovationType string          `json:"renovation_type"`
	Categories     json.RawMessage `json:"categories"`
	Status         string          `json:"status"`
	Version        int             `json:"version"`
}

type applyEstimateTemplateInput struct {
	TemplateID uuid.UUID `json:"template_id"`
}

func (h BusinessHandler) GetProjectEstimate(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	projectID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	if !h.projectBelongsToCompany(c, a.CompanyID, projectID) {
		c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
		return
	}
	item, err := h.ensureProjectEstimate(c, a, projectID)
	if err != nil {
		writeDBError(c, err, "project estimate not found")
		return
	}
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) UpdateProjectEstimate(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	projectID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	if !h.projectBelongsToCompany(c, a.CompanyID, projectID) {
		c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
		return
	}
	var input projectEstimateInput
	if !bindJSON(c, &input) {
		return
	}
	if !h.normalizeProjectEstimateInput(c, a.CompanyID, &input) {
		return
	}

	existing, err := h.ensureProjectEstimate(c, a, projectID)
	if err != nil {
		writeDBError(c, err, "project estimate not found")
		return
	}
	if input.Version > 0 && input.Version != existing.Version {
		c.JSON(http.StatusConflict, gin.H{"error": "project estimate was updated elsewhere"})
		return
	}

	var item projectEstimatePayload
	err = h.db.QueryRow(c.Request.Context(), `
		UPDATE project_estimates
		SET renovation_type=$3, categories=$4, status=$5, version=version + 1, updated_at=now(), deleted_at=NULL
		WHERE company_id=$1 AND project_id=$2
		RETURNING id, project_id, renovation_type, categories, status, version, created_at, updated_at
	`, a.CompanyID, projectID, input.RenovationType, input.Categories, input.Status).Scan(
		&item.ID, &item.ProjectID, &item.RenovationType, &item.Categories, &item.Status, &item.Version, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "project estimate not found")
		return
	}
	item.Name = "Quote Scope"
	writeAudit(h.db, c, a, "project_estimates.update", "project_estimate", item.ID, gin.H{"project_id": projectID})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) ApplyEstimateTemplateToProject(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	projectID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input applyEstimateTemplateInput
	if !bindJSON(c, &input) {
		return
	}
	template, err := h.getEstimateTemplate(c, a.CompanyID, input.TemplateID)
	if err != nil {
		writeDBError(c, err, "estimate template not found")
		return
	}
	request := projectEstimateInput{
		RenovationType: template.RenovationType,
		Categories:     template.Categories,
		Status:         "draft",
	}
	if !h.normalizeProjectEstimateInput(c, a.CompanyID, &request) {
		return
	}
	if !h.projectBelongsToCompany(c, a.CompanyID, projectID) {
		c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
		return
	}

	var item projectEstimatePayload
	err = h.db.QueryRow(c.Request.Context(), `
		INSERT INTO project_estimates (company_id, project_id, renovation_type, categories, status, created_by)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (company_id, project_id)
		DO UPDATE SET renovation_type=EXCLUDED.renovation_type, categories=EXCLUDED.categories,
		              status=EXCLUDED.status, version=project_estimates.version + 1, updated_at=now(), deleted_at=NULL
		RETURNING id, project_id, renovation_type, categories, status, version, created_at, updated_at
	`, a.CompanyID, projectID, request.RenovationType, request.Categories, request.Status, a.UserID).Scan(
		&item.ID, &item.ProjectID, &item.RenovationType, &item.Categories, &item.Status, &item.Version, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "project estimate not found")
		return
	}
	item.Name = "Quote Scope"
	writeAudit(h.db, c, a, "project_estimates.apply_template", "project_estimate", item.ID, gin.H{"project_id": projectID, "template_id": input.TemplateID})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) ImportDrawingItemsToProjectEstimate(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	projectID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	estimate, err := h.ensureProjectEstimate(c, a, projectID)
	if err != nil {
		writeDBError(c, err, "project estimate not found")
		return
	}
	categories := make([]estimateTemplateCategoryJSON, 0)
	_ = json.Unmarshal(estimate.Categories, &categories)

	importCategoryIndex := -1
	for index := range categories {
		if strings.EqualFold(categories[index].Name, "Imported Drawing Items") {
			importCategoryIndex = index
			break
		}
	}
	if importCategoryIndex == -1 {
		category := estimateTemplateCategoryJSON{
			ID:        uuid.New(),
			Name:      "Imported Drawing Items",
			Items:     []estimateTemplateItemJSON{},
			SortOrder: len(categories),
		}
		categories = append(categories, category)
		importCategoryIndex = len(categories) - 1
	}

	existingProductIDs := map[uuid.UUID]struct{}{}
	for _, category := range categories {
		for _, item := range category.Items {
			if item.ProductID != nil {
				existingProductIDs[*item.ProductID] = struct{}{}
			}
		}
	}

	rows, err := h.db.Query(c.Request.Context(), `
		SELECT o.object_type, COALESCE(COALESCE(o.product_id, o.service_id)::text, ''),
		       o.quantity::float8, COALESCE(o.unit, 'each'), COALESCE(o.notes, ''),
		       COALESCE(p.name, ''), COALESCE(p.sku, ''), COALESCE(b.name, ''),
		       COALESCE(pc.name, ''), COALESCE(p.material, '')
		FROM drawing_objects o
		LEFT JOIN products p ON p.id=COALESCE(o.product_id, o.service_id) AND p.company_id=o.company_id AND p.deleted_at IS NULL
		LEFT JOIN brands b ON b.id=p.brand_id AND b.company_id=p.company_id AND b.deleted_at IS NULL
		LEFT JOIN product_categories pc ON pc.id=p.category_id AND pc.company_id=p.company_id AND pc.deleted_at IS NULL
		WHERE o.company_id=$1 AND o.project_id=$2 AND o.deleted_at IS NULL AND o.status <> 'deleted' AND o.is_quote_enabled=true
		ORDER BY o.created_at ASC
	`, a.CompanyID, projectID)
	if err != nil {
		writeDBError(c, err, "drawing objects not found")
		return
	}
	defer rows.Close()

	for rows.Next() {
		var objectType string
		var productID *uuid.UUID
		var quantity float64
		var unit string
		var notes string
		var productName string
		var sku string
		var brand string
		var categoryName string
		var material string
		if err := rows.Scan(&objectType, uuidTextScanner(&productID), &quantity, &unit, &notes, &productName, &sku, &brand, &categoryName, &material); err != nil {
			writeDBError(c, err, "drawing objects not found")
			return
		}
		if productID != nil {
			if _, exists := existingProductIDs[*productID]; exists {
				continue
			}
			existingProductIDs[*productID] = struct{}{}
		}
		itemName := productName
		if strings.TrimSpace(itemName) == "" {
			itemName = strings.Title(strings.ReplaceAll(objectType, "_", " "))
		}
		if quantity <= 0 {
			quantity = 1
		}
		item := estimateTemplateItemJSON{
			ID:                      uuid.New(),
			ProductID:               productID,
			ProductNameSnapshot:     optionalString(productName),
			SKUSnapshot:             optionalString(sku),
			BrandSnapshot:           optionalString(brand),
			ProductCategorySnapshot: optionalString(categoryName),
			MaterialSnapshot:        optionalString(material),
			ItemName:                itemName,
			CategoryID:              categories[importCategoryIndex].ID,
			ScopeCode:               "imported_drawing_object",
			MaterialChoice:          material,
			SuppliedBy:              "TBD",
			PricingStatus:           "pending",
			Quantity:                quantity,
			Unit:                    unit,
			Notes:                   notes,
			Selected:                true,
		}
		categories[importCategoryIndex].Items = append(categories[importCategoryIndex].Items, item)
	}
	if err := rows.Err(); err != nil {
		writeDBError(c, err, "drawing objects not found")
		return
	}

	raw, err := json.Marshal(categories)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "project estimate import failed"})
		return
	}
	request := projectEstimateInput{
		RenovationType: estimate.RenovationType,
		Categories:     raw,
		Status:         estimate.Status,
		Version:        estimate.Version,
	}
	if !h.normalizeProjectEstimateInput(c, a.CompanyID, &request) {
		return
	}
	var item projectEstimatePayload
	err = h.db.QueryRow(c.Request.Context(), `
		UPDATE project_estimates
		SET categories=$3, version=version + 1, updated_at=now()
		WHERE company_id=$1 AND project_id=$2
		RETURNING id, project_id, renovation_type, categories, status, version, created_at, updated_at
	`, a.CompanyID, projectID, request.Categories).Scan(
		&item.ID, &item.ProjectID, &item.RenovationType, &item.Categories, &item.Status, &item.Version, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "project estimate not found")
		return
	}
	item.Name = "Quote Scope"
	writeAudit(h.db, c, a, "project_estimates.import_drawing", "project_estimate", item.ID, gin.H{"project_id": projectID})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) ensureProjectEstimate(c *gin.Context, a actor, projectID uuid.UUID) (projectEstimatePayload, error) {
	var item projectEstimatePayload
	err := h.db.QueryRow(c.Request.Context(), `
		INSERT INTO project_estimates (company_id, project_id, created_by)
		SELECT $1, p.id, $3
		FROM projects p
		WHERE p.company_id=$1 AND p.id=$2 AND p.deleted_at IS NULL
		ON CONFLICT (company_id, project_id) DO UPDATE SET updated_at=project_estimates.updated_at
		RETURNING id, project_id, renovation_type, categories, status, version, created_at, updated_at
	`, a.CompanyID, projectID, a.UserID).Scan(
		&item.ID, &item.ProjectID, &item.RenovationType, &item.Categories, &item.Status, &item.Version, &item.CreatedAt, &item.UpdatedAt,
	)
	item.Name = "Quote Scope"
	return item, err
}

func (h BusinessHandler) getProjectEstimateForQuote(c *gin.Context, companyID uuid.UUID, projectID uuid.UUID) (projectEstimatePayload, bool, error) {
	var item projectEstimatePayload
	err := h.db.QueryRow(c.Request.Context(), `
		SELECT id, project_id, renovation_type, categories, status, version, created_at, updated_at
		FROM project_estimates
		WHERE company_id=$1 AND project_id=$2 AND deleted_at IS NULL
	`, companyID, projectID).Scan(
		&item.ID, &item.ProjectID, &item.RenovationType, &item.Categories, &item.Status, &item.Version, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return projectEstimatePayload{}, false, nil
		}
		return projectEstimatePayload{}, false, err
	}
	item.Name = "Quote Scope"
	return item, true, nil
}

func (h BusinessHandler) normalizeProjectEstimateInput(c *gin.Context, companyID uuid.UUID, input *projectEstimateInput) bool {
	input.RenovationType = strings.TrimSpace(input.RenovationType)
	if input.RenovationType == "" {
		input.RenovationType = "custom_project"
	}
	input.Status = defaultStatus(input.Status, "draft")
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
