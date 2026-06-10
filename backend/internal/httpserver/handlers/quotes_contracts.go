package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type quoteWarningPayload struct {
	SourceObjectID       *uuid.UUID `json:"source_object_id,omitempty"`
	SourceEstimateItemID *uuid.UUID `json:"source_estimate_item_id,omitempty"`
	ObjectType           string     `json:"object_type"`
	Message              string     `json:"message"`
}

type quoteItemPayload struct {
	ID                   *uuid.UUID `json:"id,omitempty"`
	ProductID            *uuid.UUID `json:"product_id,omitempty"`
	SourceObjectID       *uuid.UUID `json:"source_object_id,omitempty"`
	SourceKind           string     `json:"source_kind"`
	SourceEstimateItemID *uuid.UUID `json:"source_estimate_item_id,omitempty"`
	ProductNameSnapshot  string     `json:"product_name_snapshot"`
	SKUSnapshot          string     `json:"sku_snapshot"`
	BrandSnapshot        string     `json:"brand_snapshot"`
	CategorySnapshot     string     `json:"category_snapshot"`
	UnitSnapshot         string     `json:"unit_snapshot"`
	UnitPriceSnapshot    float64    `json:"unit_price_snapshot"`
	Quantity             float64    `json:"quantity"`
	DiscountAmount       float64    `json:"discount_amount"`
	InstallationFee      float64    `json:"installation_fee"`
	LineTotal            float64    `json:"line_total"`
	NotesSnapshot        string     `json:"notes_snapshot"`
	IsContractVisible    bool       `json:"is_contract_visible"`
	RoomSnapshot         string     `json:"room_snapshot"`
	ScopeSnapshot        string     `json:"scope_snapshot"`
	MaterialSnapshot     string     `json:"material_snapshot"`
	SuppliedBySnapshot   string     `json:"supplied_by_snapshot"`
	PricingStatus        string     `json:"pricing_status"`
	SortOrder            int        `json:"sort_order"`
}

type quotePreviewPayload struct {
	CustomerID    uuid.UUID             `json:"customer_id"`
	CustomerName  string                `json:"customer_name"`
	ProjectID     uuid.UUID             `json:"project_id"`
	ProjectTitle  string                `json:"project_title"`
	DrawingID     *uuid.UUID            `json:"drawing_id,omitempty"`
	Items         []quoteItemPayload    `json:"items"`
	Warnings      []quoteWarningPayload `json:"warnings"`
	Currency      string                `json:"currency"`
	Subtotal      float64               `json:"subtotal"`
	DiscountTotal float64               `json:"discount_total"`
	TaxRate       float64               `json:"tax_rate"`
	TaxTotal      float64               `json:"tax_total"`
	Total         float64               `json:"total"`
}

type quotePayload struct {
	ID            uuid.UUID             `json:"id"`
	CustomerID    uuid.UUID             `json:"customer_id"`
	ProjectID     uuid.UUID             `json:"project_id"`
	DrawingID     *uuid.UUID            `json:"drawing_id,omitempty"`
	QuoteNumber   string                `json:"quote_number"`
	Status        string                `json:"status"`
	Currency      string                `json:"currency"`
	Subtotal      float64               `json:"subtotal"`
	DiscountTotal float64               `json:"discount_total"`
	TaxRate       float64               `json:"tax_rate"`
	TaxTotal      float64               `json:"tax_total"`
	Total         float64               `json:"total"`
	Snapshot      json.RawMessage       `json:"snapshot"`
	Items         []quoteItemPayload    `json:"items"`
	Warnings      []quoteWarningPayload `json:"warnings,omitempty"`
	ConfirmedAt   *time.Time            `json:"confirmed_at,omitempty"`
	CreatedAt     time.Time             `json:"created_at"`
	UpdatedAt     time.Time             `json:"updated_at"`
}

func (h BusinessHandler) PreviewQuote(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	projectID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	if _, err := h.ensureDrawing(c, a, projectID); err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	preview, err := h.buildQuotePreview(c, a.CompanyID, projectID)
	if err != nil {
		writeDBError(c, err, "quote preview not found")
		return
	}
	c.JSON(http.StatusOK, preview)
}

func (h BusinessHandler) CreateQuote(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	projectID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	if _, err := h.ensureDrawing(c, a, projectID); err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	preview, err := h.buildQuotePreview(c, a.CompanyID, projectID)
	if err != nil {
		writeDBError(c, err, "quote preview not found")
		return
	}

	tx, err := h.db.Begin(c.Request.Context())
	if err != nil {
		writeDBError(c, err, "quote not found")
		return
	}
	defer tx.Rollback(c.Request.Context())

	quoteNumber := nextDocumentNumber("Q")
	var quoteID uuid.UUID
	err = tx.QueryRow(c.Request.Context(), `
		INSERT INTO quotes (
			company_id, customer_id, project_id, drawing_id, quote_number, currency,
			subtotal, discount_total, tax_rate, tax_total, total, snapshot, created_by
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
		RETURNING id
	`, a.CompanyID, preview.CustomerID, preview.ProjectID, preview.DrawingID, quoteNumber, preview.Currency,
		preview.Subtotal, preview.DiscountTotal, preview.TaxRate, preview.TaxTotal, preview.Total,
		jsonSnapshot(preview), a.UserID).Scan(&quoteID)
	if err != nil {
		writeDBError(c, err, "quote not found")
		return
	}

	for index, item := range preview.Items {
		if _, err := tx.Exec(c.Request.Context(), `
			INSERT INTO quote_items (
				company_id, quote_id, product_id, source_object_id, source_kind, source_estimate_item_id,
				product_name_snapshot, sku_snapshot, brand_snapshot, category_snapshot, unit_snapshot,
				unit_price_snapshot, quantity, discount_amount, installation_fee, line_total,
				notes_snapshot, is_contract_visible, room_snapshot, scope_snapshot, material_snapshot,
				supplied_by_snapshot, pricing_status, sort_order
			)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
			        $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24)
		`, a.CompanyID, quoteID, item.ProductID, item.SourceObjectID, item.SourceKind, item.SourceEstimateItemID,
			item.ProductNameSnapshot, item.SKUSnapshot, item.BrandSnapshot, item.CategorySnapshot, item.UnitSnapshot,
			item.UnitPriceSnapshot, item.Quantity, item.DiscountAmount, item.InstallationFee, item.LineTotal,
			item.NotesSnapshot, item.IsContractVisible, item.RoomSnapshot, item.ScopeSnapshot, item.MaterialSnapshot,
			item.SuppliedBySnapshot, item.PricingStatus, index); err != nil {
			writeDBError(c, err, "quote item not found")
			return
		}
	}
	if err := tx.Commit(c.Request.Context()); err != nil {
		writeDBError(c, err, "quote not found")
		return
	}
	quote, err := h.getQuotePayload(c, a.CompanyID, quoteID)
	if err != nil {
		writeDBError(c, err, "quote not found")
		return
	}
	quote.Warnings = preview.Warnings
	writeAudit(h.db, c, a, "quotes.create", "quote", quote.ID, gin.H{"quote_number": quote.QuoteNumber})
	c.JSON(http.StatusCreated, quote)
}

func (h BusinessHandler) GetQuote(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	quote, err := h.getQuotePayload(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "quote not found")
		return
	}
	c.JSON(http.StatusOK, quote)
}

func (h BusinessHandler) ListQuotes(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id
		FROM quotes
		WHERE company_id=$1 AND deleted_at IS NULL
		ORDER BY created_at DESC
		LIMIT 100
	`, a.CompanyID)
	if err != nil {
		writeDBError(c, err, "quotes not found")
		return
	}
	defer rows.Close()
	ids := make([]uuid.UUID, 0)
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			writeDBError(c, err, "quotes not found")
			return
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		writeDBError(c, err, "quotes not found")
		return
	}
	items := make([]quotePayload, 0, len(ids))
	for _, id := range ids {
		quote, err := h.getQuotePayload(c, a.CompanyID, id)
		if err != nil {
			writeDBError(c, err, "quotes not found")
			return
		}
		items = append(items, quote)
	}
	c.JSON(http.StatusOK, listResponse[quotePayload]{Items: items})
}

func (h BusinessHandler) ConfirmQuote(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	tag, err := h.db.Exec(c.Request.Context(), `
		UPDATE quotes
		SET status='confirmed', confirmed_at=COALESCE(confirmed_at, now()), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "quote not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "quote not found"})
		return
	}
	quote, err := h.getQuotePayload(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "quote not found")
		return
	}
	writeAudit(h.db, c, a, "quotes.confirm", "quote", id, gin.H{"quote_number": quote.QuoteNumber})
	c.JSON(http.StatusOK, quote)
}

type objectQuoteRow struct {
	ObjectID          uuid.UUID
	ObjectType        string
	ProductID         *uuid.UUID
	Quantity          float64
	DiscountAmount    float64
	InstallationFee   float64
	ObjectNotes       string
	IsContractVisible bool
	ProductName       string
	SKU               string
	Brand             string
	Category          string
	Unit              string
	PriceText         string
}

func (h BusinessHandler) buildQuotePreview(c *gin.Context, companyID uuid.UUID, projectID uuid.UUID) (quotePreviewPayload, error) {
	var preview quotePreviewPayload
	var drawingIDText string
	err := h.db.QueryRow(c.Request.Context(), `
		SELECT p.customer_id, c.name, p.id, p.title, COALESCE(d.id::text, ''), COALESCE(co.tax_rate::float8, 0)
		FROM projects p
		JOIN customers c ON c.id=p.customer_id AND c.company_id=p.company_id AND c.deleted_at IS NULL
		JOIN companies co ON co.id=p.company_id
		LEFT JOIN drawings d ON d.company_id=p.company_id AND d.project_id=p.id
		WHERE p.company_id=$1 AND p.id=$2 AND p.deleted_at IS NULL
	`, companyID, projectID).Scan(
		&preview.CustomerID, &preview.CustomerName, &preview.ProjectID, &preview.ProjectTitle, &drawingIDText, &preview.TaxRate,
	)
	if err != nil {
		return quotePreviewPayload{}, err
	}
	preview.DrawingID = optionalUUID(drawingIDText)
	preview.Currency = "USD"

	estimate, found, err := h.getProjectEstimateForQuote(c, companyID, projectID)
	if err != nil {
		return quotePreviewPayload{}, err
	}
	if !found {
		preview.Warnings = append(preview.Warnings, quoteWarningPayload{
			ObjectType: "quote_scope",
			Message:    "No quote scope builder items found.",
		})
		return preview, nil
	}
	if err := h.appendProjectEstimateItemsToPreview(estimate, &preview); err != nil {
		return quotePreviewPayload{}, err
	}
	if len(preview.Items) == 0 {
		preview.Warnings = append(preview.Warnings, quoteWarningPayload{
			ObjectType: "quote_scope",
			Message:    "No selected quote scope items found.",
		})
	}
	return preview, nil
}

func (h BusinessHandler) appendProjectEstimateItemsToPreview(estimate projectEstimatePayload, preview *quotePreviewPayload) error {
	var categories []estimateTemplateCategoryJSON
	if err := json.Unmarshal(estimate.Categories, &categories); err != nil {
		return err
	}
	for _, category := range categories {
		categoryName := strings.TrimSpace(category.Name)
		for _, item := range category.Items {
			if !item.Selected {
				continue
			}
			itemName := strings.TrimSpace(item.ItemName)
			if itemName == "" && item.ProductNameSnapshot != nil {
				itemName = strings.TrimSpace(*item.ProductNameSnapshot)
			}
			if itemName == "" {
				itemName = "Unnamed scope item"
			}
			unit := strings.TrimSpace(item.Unit)
			if unit == "" {
				unit = "each"
			}
			quantity := item.Quantity
			if quantity <= 0 {
				quantity = 1
			}
			pricingStatus := strings.TrimSpace(item.PricingStatus)
			if pricingStatus == "" {
				pricingStatus = "pending"
			}
			material := strings.TrimSpace(item.MaterialChoice)
			if material == "" && item.MaterialSnapshot != nil {
				material = strings.TrimSpace(*item.MaterialSnapshot)
			}
			notes := strings.Join(nonEmptyStrings(item.Description, item.Notes), "\n")
			sourceID := item.ID
			preview.Items = append(preview.Items, quoteItemPayload{
				ProductID:            item.ProductID,
				SourceKind:           "estimate_item",
				SourceEstimateItemID: &sourceID,
				ProductNameSnapshot:  itemName,
				SKUSnapshot:          optionalStringValue(item.SKUSnapshot),
				BrandSnapshot:        optionalStringValue(item.BrandSnapshot),
				CategorySnapshot:     optionalStringValue(item.ProductCategorySnapshot),
				UnitSnapshot:         unit,
				UnitPriceSnapshot:    0,
				Quantity:             quantity,
				DiscountAmount:       0,
				InstallationFee:      0,
				LineTotal:            0,
				NotesSnapshot:        notes,
				IsContractVisible:    true,
				RoomSnapshot:         firstNonEmpty(item.RoomName, item.RoomType, item.FloorLevel),
				ScopeSnapshot:        firstNonEmpty(categoryName, item.ScopeCode),
				MaterialSnapshot:     material,
				SuppliedBySnapshot:   firstNonEmpty(item.SuppliedBy, "TBD"),
				PricingStatus:        pricingStatus,
				SortOrder:            len(preview.Items),
			})
			for _, risk := range item.RiskFlags {
				risk = strings.TrimSpace(risk)
				if risk == "" {
					continue
				}
				riskSourceID := item.ID
				preview.Warnings = append(preview.Warnings, quoteWarningPayload{
					SourceEstimateItemID: &riskSourceID,
					ObjectType:           itemName,
					Message:              risk,
				})
			}
		}
	}
	return nil
}

func (h BusinessHandler) annotationNotesByObject(c *gin.Context, companyID uuid.UUID, projectID uuid.UUID) (map[uuid.UUID]string, error) {
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT linked_object_id, string_agg(text, E'\n' ORDER BY created_at)
		FROM drawing_annotations
		WHERE company_id=$1 AND project_id=$2 AND deleted_at IS NULL AND linked_object_id IS NOT NULL
		GROUP BY linked_object_id
	`, companyID, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[uuid.UUID]string{}
	for rows.Next() {
		var id uuid.UUID
		var notes string
		if err := rows.Scan(&id, &notes); err != nil {
			return nil, err
		}
		out[id] = notes
	}
	return out, rows.Err()
}

func (h BusinessHandler) getQuotePayload(c *gin.Context, companyID uuid.UUID, quoteID uuid.UUID) (quotePayload, error) {
	var quote quotePayload
	var drawingIDText string
	var snapshot []byte
	err := h.db.QueryRow(c.Request.Context(), `
		SELECT id, customer_id, project_id, COALESCE(drawing_id::text, ''), quote_number, status, currency,
		       subtotal::float8, discount_total::float8, tax_rate::float8, tax_total::float8, total::float8,
		       snapshot, confirmed_at, created_at, updated_at
		FROM quotes
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, companyID, quoteID).Scan(
		&quote.ID, &quote.CustomerID, &quote.ProjectID, &drawingIDText, &quote.QuoteNumber, &quote.Status, &quote.Currency,
		&quote.Subtotal, &quote.DiscountTotal, &quote.TaxRate, &quote.TaxTotal, &quote.Total,
		&snapshot, timePtrScanner(&quote.ConfirmedAt), &quote.CreatedAt, &quote.UpdatedAt,
	)
	if err != nil {
		return quotePayload{}, err
	}
	quote.DrawingID = optionalUUID(drawingIDText)
	quote.Snapshot = json.RawMessage(snapshot)
	items, err := h.listQuoteItems(c, companyID, quoteID)
	if err != nil {
		return quotePayload{}, err
	}
	quote.Items = items
	return quote, nil
}

func (h BusinessHandler) listQuoteItems(c *gin.Context, companyID uuid.UUID, quoteID uuid.UUID) ([]quoteItemPayload, error) {
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id, COALESCE(product_id::text, ''), COALESCE(source_object_id::text, ''),
		       source_kind, COALESCE(source_estimate_item_id::text, ''),
		       product_name_snapshot, COALESCE(sku_snapshot, ''),
		       COALESCE(brand_snapshot, ''), COALESCE(category_snapshot, ''), unit_snapshot,
		       unit_price_snapshot::float8, quantity::float8, discount_amount::float8, installation_fee::float8,
		       line_total::float8, COALESCE(notes_snapshot, ''), is_contract_visible,
		       COALESCE(room_snapshot, ''), COALESCE(scope_snapshot, ''), COALESCE(material_snapshot, ''),
		       COALESCE(supplied_by_snapshot, ''), pricing_status, sort_order
		FROM quote_items
		WHERE company_id=$1 AND quote_id=$2
		ORDER BY sort_order ASC, created_at ASC
	`, companyID, quoteID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]quoteItemPayload, 0)
	for rows.Next() {
		var item quoteItemPayload
		var id uuid.UUID
		if err := rows.Scan(
			&id, uuidTextScanner(&item.ProductID), uuidTextScanner(&item.SourceObjectID),
			&item.SourceKind, uuidTextScanner(&item.SourceEstimateItemID),
			&item.ProductNameSnapshot, &item.SKUSnapshot,
			&item.BrandSnapshot, &item.CategorySnapshot, &item.UnitSnapshot, &item.UnitPriceSnapshot,
			&item.Quantity, &item.DiscountAmount, &item.InstallationFee, &item.LineTotal,
			&item.NotesSnapshot, &item.IsContractVisible, &item.RoomSnapshot, &item.ScopeSnapshot,
			&item.MaterialSnapshot, &item.SuppliedBySnapshot, &item.PricingStatus, &item.SortOrder,
		); err != nil {
			return nil, err
		}
		item.ID = &id
		if item.SourceKind == "" {
			item.SourceKind = "drawing_object"
		}
		if item.PricingStatus == "" {
			item.PricingStatus = "pending"
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

type contractPayload struct {
	ID                 uuid.UUID       `json:"id"`
	QuoteID            uuid.UUID       `json:"quote_id"`
	ContractTemplateID *uuid.UUID      `json:"contract_template_id,omitempty"`
	PDFFileAssetID     *uuid.UUID      `json:"pdf_file_asset_id,omitempty"`
	ContractNumber     string          `json:"contract_number"`
	Status             string          `json:"status"`
	PaymentTerms       string          `json:"payment_terms"`
	DeliveryTerms      string          `json:"delivery_terms"`
	Disclaimer         string          `json:"disclaimer"`
	Snapshot           json.RawMessage `json:"snapshot"`
	IssuedAt           *time.Time      `json:"issued_at,omitempty"`
	SignedAt           *time.Time      `json:"signed_at,omitempty"`
	CreatedAt          time.Time       `json:"created_at"`
	UpdatedAt          time.Time       `json:"updated_at"`
}

func (h BusinessHandler) CreateContract(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	quoteID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	quote, err := h.getQuotePayload(c, a.CompanyID, quoteID)
	if err != nil {
		writeDBError(c, err, "quote not found")
		return
	}
	contractNumber := nextDocumentNumber("C")
	var contractID uuid.UUID
	err = h.db.QueryRow(c.Request.Context(), `
		INSERT INTO contracts (
			company_id, quote_id, contract_number, payment_terms, delivery_terms, disclaimer, snapshot, created_by
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id
	`, a.CompanyID, quote.ID, contractNumber,
		"Deposit due at signing. Balance due according to project milestones.",
		"Schedule and delivery are subject to material availability and approved scope.",
		"Changes outside the approved scope require a written change order.",
		jsonSnapshot(quote), a.UserID).Scan(&contractID)
	if err != nil {
		writeDBError(c, err, "contract not found")
		return
	}
	contract, err := h.getContractPayload(c, a.CompanyID, contractID)
	if err != nil {
		writeDBError(c, err, "contract not found")
		return
	}
	writeAudit(h.db, c, a, "contracts.create", "contract", contract.ID, gin.H{"contract_number": contract.ContractNumber})
	c.JSON(http.StatusCreated, contract)
}

func (h BusinessHandler) GetContract(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	contract, err := h.getContractPayload(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "contract not found")
		return
	}
	c.JSON(http.StatusOK, contract)
}

func (h BusinessHandler) ListContracts(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id
		FROM contracts
		WHERE company_id=$1 AND deleted_at IS NULL
		ORDER BY created_at DESC
		LIMIT 100
	`, a.CompanyID)
	if err != nil {
		writeDBError(c, err, "contracts not found")
		return
	}
	defer rows.Close()
	ids := make([]uuid.UUID, 0)
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			writeDBError(c, err, "contracts not found")
			return
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		writeDBError(c, err, "contracts not found")
		return
	}
	items := make([]contractPayload, 0, len(ids))
	for _, id := range ids {
		contract, err := h.getContractPayload(c, a.CompanyID, id)
		if err != nil {
			writeDBError(c, err, "contracts not found")
			return
		}
		items = append(items, contract)
	}
	c.JSON(http.StatusOK, listResponse[contractPayload]{Items: items})
}

func (h BusinessHandler) CreateContractPDFRecord(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	contract, err := h.getContractPayload(c, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "contract not found")
		return
	}
	assetID := uuid.New()
	objectKey := fmt.Sprintf("companies/%s/contracts/%s/%s.pdf", a.CompanyID, contract.ID, contract.ContractNumber)
	tx, err := h.db.Begin(c.Request.Context())
	if err != nil {
		writeDBError(c, err, "contract not found")
		return
	}
	defer tx.Rollback(c.Request.Context())
	if _, err := tx.Exec(c.Request.Context(), `
		INSERT INTO file_assets (id, company_id, owner_type, owner_id, bucket, object_key, original_filename, mime_type, status, created_by)
		VALUES ($1, $2, 'contract', $3, 'local-dev-quoter', $4, $5, 'application/pdf', 'pending_upload', $6)
	`, assetID, a.CompanyID, contract.ID, objectKey, contract.ContractNumber+".pdf", a.UserID); err != nil {
		writeDBError(c, err, "file asset not found")
		return
	}
	if _, err := tx.Exec(c.Request.Context(), `
		UPDATE contracts
		SET pdf_file_asset_id=$3, status='issued', issued_at=COALESCE(issued_at, now()), updated_at=now()
		WHERE company_id=$1 AND id=$2
	`, a.CompanyID, contract.ID, assetID); err != nil {
		writeDBError(c, err, "contract not found")
		return
	}
	if err := tx.Commit(c.Request.Context()); err != nil {
		writeDBError(c, err, "contract not found")
		return
	}
	updated, err := h.getContractPayload(c, a.CompanyID, contract.ID)
	if err != nil {
		writeDBError(c, err, "contract not found")
		return
	}
	writeAudit(h.db, c, a, "contracts.pdf_record", "contract", contract.ID, gin.H{"asset_id": assetID})
	c.JSON(http.StatusCreated, updated)
}

func (h BusinessHandler) GetContractDownloadURL(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var assetID uuid.UUID
	var objectKey string
	if err := h.db.QueryRow(c.Request.Context(), `
		SELECT fa.id, fa.object_key
		FROM contracts c
		JOIN file_assets fa ON fa.id=c.pdf_file_asset_id AND fa.company_id=c.company_id
		WHERE c.company_id=$1 AND c.id=$2 AND c.deleted_at IS NULL
	`, a.CompanyID, id).Scan(&assetID, &objectKey); err != nil {
		writeDBError(c, err, "contract PDF not found")
		return
	}
	scheme := c.GetHeader("X-Forwarded-Proto")
	if scheme == "" {
		scheme = "http"
	}
	c.JSON(http.StatusOK, gin.H{
		"asset_id":   assetID,
		"object_key": objectKey,
		"url":        fmt.Sprintf("%s://%s/api/v1/file-assets/%s/download", scheme, c.Request.Host, assetID),
		"expires_at": nowUTC().Add(15 * time.Minute),
	})
}

func (h BusinessHandler) getContractPayload(c *gin.Context, companyID uuid.UUID, contractID uuid.UUID) (contractPayload, error) {
	var contract contractPayload
	var templateIDText string
	var pdfIDText string
	var snapshot []byte
	err := h.db.QueryRow(c.Request.Context(), `
		SELECT id, quote_id, COALESCE(contract_template_id::text, ''), COALESCE(pdf_file_asset_id::text, ''),
		       contract_number, status, payment_terms, delivery_terms, disclaimer, snapshot,
		       issued_at, signed_at, created_at, updated_at
		FROM contracts
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, companyID, contractID).Scan(
		&contract.ID, &contract.QuoteID, &templateIDText, &pdfIDText, &contract.ContractNumber, &contract.Status,
		&contract.PaymentTerms, &contract.DeliveryTerms, &contract.Disclaimer, &snapshot,
		timePtrScanner(&contract.IssuedAt), timePtrScanner(&contract.SignedAt), &contract.CreatedAt, &contract.UpdatedAt,
	)
	if err != nil {
		return contractPayload{}, err
	}
	contract.ContractTemplateID = optionalUUID(templateIDText)
	contract.PDFFileAssetID = optionalUUID(pdfIDText)
	contract.Snapshot = json.RawMessage(snapshot)
	return contract, nil
}

func nextDocumentNumber(prefix string) string {
	return fmt.Sprintf("%s-%s-%s", prefix, time.Now().UTC().Format("20060102-150405"), strings.ToUpper(uuid.NewString()[:6]))
}

func nonEmptyStrings(values ...string) []string {
	out := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			out = append(out, value)
		}
	}
	return out
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			return value
		}
	}
	return ""
}

func optionalStringValue(value *string) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(*value)
}
