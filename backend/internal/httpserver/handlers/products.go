package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"quoter/backend/internal/domain/catalog"
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

type productMatchPayload struct {
	Product         productPayload `json:"product"`
	Score           float64        `json:"score"`
	Reasons         []string       `json:"reasons"`
	MatchedKeywords []string       `json:"matched_keywords"`
	MatchedSize     *string        `json:"matched_size,omitempty"`
	MatchedColor    *string        `json:"matched_color,omitempty"`
	MatchedCategory *string        `json:"matched_category,omitempty"`
}

func (h BusinessHandler) ListBrands(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	items, err := h.catalog.ListBrands(c.Request.Context(), a.CompanyID)
	if err != nil {
		writeCatalogError(c, err, "brands not found")
		return
	}
	c.JSON(http.StatusOK, listResponse[brandPayload]{Items: mapBrands(items)})
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
	item, err := h.catalog.CreateBrand(c.Request.Context(), a.CompanyID, catalog.BrandInput{Name: input.Name})
	if err != nil {
		writeCatalogError(c, err, "brand not found")
		return
	}
	writeAudit(h.db, c, a, "brands.create", "brand", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusCreated, brandToPayload(item))
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
	item, err := h.catalog.UpdateBrand(c.Request.Context(), a.CompanyID, id, catalog.BrandInput{Name: input.Name})
	if err != nil {
		writeCatalogError(c, err, "brand not found")
		return
	}
	writeAudit(h.db, c, a, "brands.update", "brand", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusOK, brandToPayload(item))
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
	if err := h.catalog.DeleteBrand(c.Request.Context(), a.CompanyID, id); err != nil {
		writeCatalogError(c, err, "brand not found")
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
	items, err := h.catalog.ListCategories(c.Request.Context(), a.CompanyID)
	if err != nil {
		writeCatalogError(c, err, "product categories not found")
		return
	}
	c.JSON(http.StatusOK, listResponse[productCategoryPayload]{Items: mapCategories(items)})
}

func (h BusinessHandler) CreateProductCategory(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	var input productCategoryInput
	if !bindJSON(c, &input) {
		return
	}
	item, err := h.catalog.CreateCategory(c.Request.Context(), a.CompanyID, catalog.CategoryInput{
		ParentID: input.ParentID,
		Name:     input.Name,
		Kind:     input.Kind,
	})
	if err != nil {
		writeCatalogError(c, err, "product category not found")
		return
	}
	writeAudit(h.db, c, a, "product_categories.create", "product_category", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusCreated, categoryToPayload(item))
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
	if !bindJSON(c, &input) {
		return
	}
	item, err := h.catalog.UpdateCategory(c.Request.Context(), a.CompanyID, id, catalog.CategoryInput{
		ParentID: input.ParentID,
		Name:     input.Name,
		Kind:     input.Kind,
	})
	if err != nil {
		writeCatalogError(c, err, "product category not found")
		return
	}
	writeAudit(h.db, c, a, "product_categories.update", "product_category", item.ID, gin.H{"name": item.Name})
	c.JSON(http.StatusOK, categoryToPayload(item))
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
	if err := h.catalog.DeleteCategory(c.Request.Context(), a.CompanyID, id); err != nil {
		writeCatalogError(c, err, "product category not found")
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
	filter, ok := productFilterFromQuery(c)
	if !ok {
		return
	}
	items, err := h.catalog.ListProducts(c.Request.Context(), a.CompanyID, filter)
	if err != nil {
		writeCatalogError(c, err, "products not found")
		return
	}
	c.JSON(http.StatusOK, listResponse[productPayload]{Items: mapProducts(items)})
}

func (h BusinessHandler) CreateProduct(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	var input productInput
	if !bindJSON(c, &input) {
		return
	}
	item, err := h.catalog.CreateProduct(c.Request.Context(), a.CompanyID, productInputToDomain(input))
	if err != nil {
		writeCatalogError(c, err, "product category not found")
		return
	}
	writeAudit(h.db, c, a, "products.create", "product", item.ID, gin.H{"sku": item.SKU})
	c.JSON(http.StatusCreated, productToPayload(item))
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
	item, err := h.catalog.GetProduct(c.Request.Context(), a.CompanyID, id)
	if err != nil {
		writeCatalogError(c, err, "product not found")
		return
	}
	c.JSON(http.StatusOK, productToPayload(item))
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
	if !bindJSON(c, &input) {
		return
	}
	item, err := h.catalog.UpdateProduct(c.Request.Context(), a.CompanyID, id, productInputToDomain(input))
	if err != nil {
		writeCatalogError(c, err, "product not found")
		return
	}
	writeAudit(h.db, c, a, "products.update", "product", item.ID, gin.H{"sku": item.SKU})
	c.JSON(http.StatusOK, productToPayload(item))
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
	if err := h.catalog.DeleteProduct(c.Request.Context(), a.CompanyID, id); err != nil {
		writeCatalogError(c, err, "product not found")
		return
	}
	writeAudit(h.db, c, a, "products.delete", "product", id, nil)
	c.Status(http.StatusNoContent)
}

func (h BusinessHandler) RecommendProducts(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	results, err := h.catalog.RecommendProducts(c.Request.Context(), a.CompanyID, catalog.RecommendationInput{
		ObjectType: c.Query("object_type"),
		Annotation: c.Query("annotation"),
		RoomType:   c.DefaultQuery("room_type", "bathroom"),
	})
	if err != nil {
		writeCatalogError(c, err, "products not found")
		return
	}
	c.JSON(http.StatusOK, listResponse[productMatchPayload]{Items: mapProductMatches(results)})
}

func productFilterFromQuery(c *gin.Context) (catalog.ProductFilter, bool) {
	filter := catalog.ProductFilter{
		Query:      c.Query("q"),
		ActiveOnly: c.DefaultQuery("active", "true") != "false",
	}
	if categoryID := c.Query("category_id"); categoryID != "" {
		id, err := uuid.Parse(categoryID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid category_id"})
			return filter, false
		}
		filter.CategoryID = &id
	}
	if brandID := c.Query("brand_id"); brandID != "" {
		id, err := uuid.Parse(brandID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid brand_id"})
			return filter, false
		}
		filter.BrandID = &id
	}
	return filter, true
}

func productInputToDomain(input productInput) catalog.ProductInput {
	return catalog.ProductInput{
		BrandID:      input.BrandID,
		CategoryID:   input.CategoryID,
		Name:         input.Name,
		SKU:          input.SKU,
		Size:         input.Size,
		Color:        input.Color,
		Material:     input.Material,
		Unit:         input.Unit,
		Description:  input.Description,
		ImageURL:     input.ImageURL,
		Active:       input.Active,
		IsService:    input.IsService,
		CurrentPrice: input.CurrentPrice,
		Currency:     input.Currency,
	}
}

func mapBrands(items []catalog.Brand) []brandPayload {
	out := make([]brandPayload, 0, len(items))
	for _, item := range items {
		out = append(out, brandToPayload(item))
	}
	return out
}

func brandToPayload(item catalog.Brand) brandPayload {
	return brandPayload{
		ID:        item.ID,
		Name:      item.Name,
		Status:    item.Status,
		CreatedAt: item.CreatedAt,
		UpdatedAt: item.UpdatedAt,
	}
}

func mapCategories(items []catalog.Category) []productCategoryPayload {
	out := make([]productCategoryPayload, 0, len(items))
	for _, item := range items {
		out = append(out, categoryToPayload(item))
	}
	return out
}

func categoryToPayload(item catalog.Category) productCategoryPayload {
	return productCategoryPayload{
		ID:        item.ID,
		ParentID:  item.ParentID,
		Name:      item.Name,
		Kind:      item.Kind,
		Status:    item.Status,
		CreatedAt: item.CreatedAt,
		UpdatedAt: item.UpdatedAt,
	}
}

func mapProducts(items []catalog.Product) []productPayload {
	out := make([]productPayload, 0, len(items))
	for _, item := range items {
		out = append(out, productToPayload(item))
	}
	return out
}

func productToPayload(item catalog.Product) productPayload {
	return productPayload{
		ID:             item.ID,
		BrandID:        item.BrandID,
		Brand:          item.Brand,
		CategoryID:     item.CategoryID,
		Category:       item.Category,
		CategoryKind:   item.CategoryKind,
		Name:           item.Name,
		SKU:            item.SKU,
		Size:           item.Size,
		Color:          item.Color,
		Material:       item.Material,
		Unit:           item.Unit,
		Description:    item.Description,
		ImageURL:       item.ImageURL,
		Active:         item.Active,
		IsService:      item.IsService,
		Status:         item.Status,
		CurrentPriceID: item.CurrentPriceID,
		Currency:       item.Currency,
		CurrentPrice:   item.CurrentPrice,
		CreatedAt:      item.CreatedAt,
		UpdatedAt:      item.UpdatedAt,
	}
}

func mapProductMatches(items []catalog.ProductMatch) []productMatchPayload {
	out := make([]productMatchPayload, 0, len(items))
	for _, item := range items {
		out = append(out, productMatchPayload{
			Product:         productToPayload(item.Product),
			Score:           item.Score,
			Reasons:         item.Reasons,
			MatchedKeywords: item.MatchedKeywords,
			MatchedSize:     item.MatchedSize,
			MatchedColor:    item.MatchedColor,
			MatchedCategory: item.MatchedCategory,
		})
	}
	return out
}

func writeCatalogError(c *gin.Context, err error, notFoundMessage string) {
	var validation catalog.ValidationError
	if errors.As(err, &validation) || errors.Is(err, catalog.ErrValidation) {
		c.JSON(http.StatusBadRequest, gin.H{"error": validation.Message})
		return
	}
	writeDBError(c, err, notFoundMessage)
}
