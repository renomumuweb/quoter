package handlers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type drawingPayload struct {
	ID                 uuid.UUID  `json:"id"`
	ProjectID          uuid.UUID  `json:"project_id"`
	DrawingFileAssetID *uuid.UUID `json:"drawing_file_asset_id,omitempty"`
	PreviewFileAssetID *uuid.UUID `json:"preview_file_asset_id,omitempty"`
	CanvasWidth        float64    `json:"canvas_width"`
	CanvasHeight       float64    `json:"canvas_height"`
	Status             string     `json:"status"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

type drawingResponse struct {
	Drawing     drawingPayload             `json:"drawing"`
	Objects     []drawingObjectPayload     `json:"objects"`
	Annotations []drawingAnnotationPayload `json:"annotations"`
}

type drawingInput struct {
	CanvasWidth        float64    `json:"canvas_width"`
	CanvasHeight       float64    `json:"canvas_height"`
	Status             string     `json:"status"`
	DrawingFileAssetID *uuid.UUID `json:"drawing_file_asset_id"`
	PreviewFileAssetID *uuid.UUID `json:"preview_file_asset_id"`
}

func (h BusinessHandler) GetDrawing(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	projectID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	drawing, err := h.ensureDrawing(c, a, projectID)
	if err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	h.writeDrawingResponse(c, a, drawing)
}

func (h BusinessHandler) UpdateDrawing(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	projectID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input drawingInput
	if !bindJSON(c, &input) {
		return
	}
	drawing, err := h.ensureDrawing(c, a, projectID)
	if err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	if input.CanvasWidth <= 0 {
		input.CanvasWidth = drawing.CanvasWidth
	}
	if input.CanvasHeight <= 0 {
		input.CanvasHeight = drawing.CanvasHeight
	}
	input.Status = defaultStatus(input.Status, drawing.Status)

	err = h.db.QueryRow(c.Request.Context(), `
		UPDATE drawings
		SET canvas_width=$3, canvas_height=$4, status=$5,
		    drawing_file_asset_id=COALESCE($6, drawing_file_asset_id),
		    preview_file_asset_id=COALESCE($7, preview_file_asset_id),
		    updated_at=now()
		WHERE company_id=$1 AND id=$2
		RETURNING id, project_id, COALESCE(drawing_file_asset_id::text, ''), COALESCE(preview_file_asset_id::text, ''),
		          canvas_width::float8, canvas_height::float8, status, created_at, updated_at
	`, a.CompanyID, drawing.ID, input.CanvasWidth, input.CanvasHeight, input.Status, input.DrawingFileAssetID, input.PreviewFileAssetID).Scan(
		&drawing.ID, &drawing.ProjectID, uuidTextScanner(&drawing.DrawingFileAssetID), uuidTextScanner(&drawing.PreviewFileAssetID),
		&drawing.CanvasWidth, &drawing.CanvasHeight, &drawing.Status, &drawing.CreatedAt, &drawing.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "drawing not found")
		return
	}
	writeAudit(h.db, c, a, "drawings.update", "drawing", drawing.ID, gin.H{"project_id": projectID})
	h.writeDrawingResponse(c, a, drawing)
}

type uploadURLInput struct {
	FileName  string `json:"file_name"`
	MimeType  string `json:"mime_type"`
	OwnerType string `json:"owner_type"`
}

type uploadURLResponse struct {
	AssetID   uuid.UUID         `json:"asset_id"`
	Bucket    string            `json:"bucket"`
	ObjectKey string            `json:"object_key"`
	UploadURL string            `json:"upload_url"`
	Method    string            `json:"method"`
	Headers   map[string]string `json:"headers"`
}

func (h BusinessHandler) CreateDrawingUploadURL(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	projectID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	drawing, err := h.ensureDrawing(c, a, projectID)
	if err != nil {
		writeDBError(c, err, "project not found")
		return
	}
	var input uploadURLInput
	_ = c.ShouldBindJSON(&input)
	if strings.TrimSpace(input.FileName) == "" {
		input.FileName = "drawing.data"
	}
	if strings.TrimSpace(input.MimeType) == "" {
		input.MimeType = "application/octet-stream"
	}
	if strings.TrimSpace(input.OwnerType) == "" {
		input.OwnerType = "drawing"
	}

	assetID := uuid.New()
	objectKey := fmt.Sprintf("companies/%s/projects/%s/drawings/%s/%s", a.CompanyID, projectID, assetID, filepath.Base(input.FileName))
	bucket := "local-dev-quoter"
	if err := h.db.QueryRow(c.Request.Context(), `
		INSERT INTO file_assets (id, company_id, owner_type, owner_id, bucket, object_key, original_filename, mime_type, status, created_by)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending_upload', $9)
		RETURNING id
	`, assetID, a.CompanyID, input.OwnerType, drawing.ID, bucket, objectKey, input.FileName, input.MimeType, a.UserID).Scan(&assetID); err != nil {
		writeDBError(c, err, "file asset not found")
		return
	}

	scheme := c.GetHeader("X-Forwarded-Proto")
	if scheme == "" {
		scheme = "http"
	}
	uploadURL := fmt.Sprintf("%s://%s/api/v1/file-assets/%s/upload", scheme, c.Request.Host, assetID)
	c.JSON(http.StatusCreated, uploadURLResponse{
		AssetID:   assetID,
		Bucket:    bucket,
		ObjectKey: objectKey,
		UploadURL: uploadURL,
		Method:    http.MethodPut,
		Headers:   map[string]string{"Content-Type": input.MimeType},
	})
}

func (h BusinessHandler) UploadFileAsset(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	assetID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var objectKey string
	var mimeType string
	if err := h.db.QueryRow(c.Request.Context(), `
		SELECT object_key, COALESCE(mime_type, 'application/octet-stream')
		FROM file_assets
		WHERE company_id=$1 AND id=$2 AND status <> 'deleted'
	`, a.CompanyID, assetID).Scan(&objectKey, &mimeType); err != nil {
		writeDBError(c, err, "file asset not found")
		return
	}

	targetDir := filepath.Join("uploads", a.CompanyID.String())
	if err := os.MkdirAll(targetDir, 0o755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to prepare upload directory"})
		return
	}
	targetPath := filepath.Join(targetDir, assetID.String())
	file, err := os.Create(targetPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create upload file"})
		return
	}
	defer file.Close()

	size, err := io.Copy(file, c.Request.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save upload"})
		return
	}
	if _, err := h.db.Exec(c.Request.Context(), `
		UPDATE file_assets
		SET status='active', size_bytes=$3, mime_type=COALESCE(NULLIF($4, ''), mime_type), updated_at=now()
		WHERE company_id=$1 AND id=$2
	`, a.CompanyID, assetID, size, c.GetHeader("Content-Type")); err != nil {
		writeDBError(c, err, "file asset not found")
		return
	}
	writeAudit(h.db, c, a, "file_assets.upload", "file_asset", assetID, gin.H{"object_key": objectKey, "mime_type": mimeType, "size_bytes": size})
	c.JSON(http.StatusOK, gin.H{"asset_id": assetID, "size_bytes": size, "status": "active"})
}

func (h BusinessHandler) DownloadFileAsset(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	assetID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var filename string
	if err := h.db.QueryRow(c.Request.Context(), `
		SELECT COALESCE(original_filename, id::text)
		FROM file_assets
		WHERE company_id=$1 AND id=$2 AND status <> 'deleted'
	`, a.CompanyID, assetID).Scan(&filename); err != nil {
		writeDBError(c, err, "file asset not found")
		return
	}
	targetPath := filepath.Join("uploads", a.CompanyID.String(), assetID.String())
	if _, err := os.Stat(targetPath); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "uploaded file not found"})
		return
	}
	c.FileAttachment(targetPath, filename)
}

type drawingObjectPayload struct {
	ID                uuid.UUID  `json:"id"`
	ProjectID         uuid.UUID  `json:"project_id"`
	DrawingID         uuid.UUID  `json:"drawing_id"`
	ObjectType        string     `json:"object_type"`
	ProductID         *uuid.UUID `json:"product_id,omitempty"`
	ServiceID         *uuid.UUID `json:"service_id,omitempty"`
	CategoryID        *uuid.UUID `json:"category_id,omitempty"`
	X                 float64    `json:"x"`
	Y                 float64    `json:"y"`
	Width             float64    `json:"width"`
	Height            float64    `json:"height"`
	Rotation          float64    `json:"rotation"`
	Quantity          float64    `json:"quantity"`
	Unit              string     `json:"unit"`
	DiscountAmount    float64    `json:"discount_amount"`
	InstallationFee   float64    `json:"installation_fee"`
	Notes             string     `json:"notes"`
	IsQuoteEnabled    bool       `json:"is_quote_enabled"`
	IsContractVisible bool       `json:"is_contract_visible"`
	Status            string     `json:"status"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

type drawingObjectInput struct {
	ProjectID         uuid.UUID  `json:"project_id"`
	DrawingID         uuid.UUID  `json:"drawing_id"`
	ObjectType        string     `json:"object_type"`
	ProductID         *uuid.UUID `json:"product_id"`
	ServiceID         *uuid.UUID `json:"service_id"`
	CategoryID        *uuid.UUID `json:"category_id"`
	X                 float64    `json:"x"`
	Y                 float64    `json:"y"`
	Width             float64    `json:"width"`
	Height            float64    `json:"height"`
	Rotation          float64    `json:"rotation"`
	Quantity          float64    `json:"quantity"`
	Unit              string     `json:"unit"`
	DiscountAmount    float64    `json:"discount_amount"`
	InstallationFee   float64    `json:"installation_fee"`
	Notes             string     `json:"notes"`
	IsQuoteEnabled    *bool      `json:"is_quote_enabled"`
	IsContractVisible *bool      `json:"is_contract_visible"`
}

func (h BusinessHandler) CreateDrawingObject(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	var input drawingObjectInput
	if !bindJSON(c, &input) {
		return
	}
	if !normalizeDrawingObjectInput(c, &input) {
		return
	}
	drawing, err := h.resolveDrawingForObject(c, a, input.ProjectID, input.DrawingID)
	if err != nil {
		writeDBError(c, err, "drawing not found")
		return
	}
	item, err := h.insertDrawingObject(c, a, drawing, input)
	if err != nil {
		writeDBError(c, err, "drawing object not found")
		return
	}
	writeAudit(h.db, c, a, "drawing_objects.create", "drawing_object", item.ID, gin.H{"project_id": item.ProjectID})
	c.JSON(http.StatusCreated, item)
}

func (h BusinessHandler) UpdateDrawingObject(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input drawingObjectInput
	if !bindJSON(c, &input) {
		return
	}
	if !normalizeDrawingObjectInput(c, &input) {
		return
	}
	isQuoteEnabled := true
	if input.IsQuoteEnabled != nil {
		isQuoteEnabled = *input.IsQuoteEnabled
	}
	isContractVisible := true
	if input.IsContractVisible != nil {
		isContractVisible = *input.IsContractVisible
	}
	var item drawingObjectPayload
	err := h.db.QueryRow(c.Request.Context(), `
		UPDATE drawing_objects
		SET object_type=$3,
		    product_id=(CASE WHEN $4::uuid IS NULL THEN NULL ELSE (SELECT id FROM products WHERE company_id=$1 AND id=$4 AND deleted_at IS NULL) END),
		    service_id=(CASE WHEN $5::uuid IS NULL THEN NULL ELSE (SELECT id FROM products WHERE company_id=$1 AND id=$5 AND deleted_at IS NULL) END),
		    category_id=(CASE WHEN $6::uuid IS NULL THEN NULL ELSE (SELECT id FROM product_categories WHERE company_id=$1 AND id=$6 AND deleted_at IS NULL) END),
		    x=$7, y=$8, width=$9, height=$10, rotation=$11, quantity=$12, unit=$13,
		    discount_amount=$14, installation_fee=$15, notes=$16,
		    is_quote_enabled=$17, is_contract_visible=$18, updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, project_id, drawing_id, object_type,
		          COALESCE(product_id::text, ''), COALESCE(service_id::text, ''), COALESCE(category_id::text, ''),
		          x::float8, y::float8, width::float8, height::float8, rotation::float8, quantity::float8, unit,
		          discount_amount::float8, installation_fee::float8, COALESCE(notes, ''),
		          is_quote_enabled, is_contract_visible, status, created_at, updated_at
	`, a.CompanyID, id, input.ObjectType, input.ProductID, input.ServiceID, input.CategoryID,
		input.X, input.Y, input.Width, input.Height, input.Rotation, input.Quantity, input.Unit,
		input.DiscountAmount, input.InstallationFee, input.Notes, isQuoteEnabled, isContractVisible).Scan(
		&item.ID, &item.ProjectID, &item.DrawingID, &item.ObjectType,
		uuidTextScanner(&item.ProductID), uuidTextScanner(&item.ServiceID), uuidTextScanner(&item.CategoryID),
		&item.X, &item.Y, &item.Width, &item.Height, &item.Rotation, &item.Quantity, &item.Unit,
		&item.DiscountAmount, &item.InstallationFee, &item.Notes,
		&item.IsQuoteEnabled, &item.IsContractVisible, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "drawing object not found")
		return
	}
	writeAudit(h.db, c, a, "drawing_objects.update", "drawing_object", item.ID, gin.H{"project_id": item.ProjectID})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) DeleteDrawingObject(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	tag, err := h.db.Exec(c.Request.Context(), `
		UPDATE drawing_objects
		SET status='deleted', deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "drawing object not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "drawing object not found"})
		return
	}
	writeAudit(h.db, c, a, "drawing_objects.delete", "drawing_object", id, nil)
	c.Status(http.StatusNoContent)
}

type drawingAnnotationPayload struct {
	ID                uuid.UUID  `json:"id"`
	ProjectID         uuid.UUID  `json:"project_id"`
	DrawingID         uuid.UUID  `json:"drawing_id"`
	AnnotationType    string     `json:"annotation_type"`
	Text              string     `json:"text"`
	X                 float64    `json:"x"`
	Y                 float64    `json:"y"`
	Width             float64    `json:"width"`
	Height            float64    `json:"height"`
	Rotation          float64    `json:"rotation"`
	LinkedObjectID    *uuid.UUID `json:"linked_object_id,omitempty"`
	LinkedProductID   *uuid.UUID `json:"linked_product_id,omitempty"`
	LinkedQuoteItemID *uuid.UUID `json:"linked_quote_item_id,omitempty"`
	ExportToPDF       bool       `json:"export_to_pdf"`
	ShowInContract    bool       `json:"show_in_contract"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

type drawingAnnotationInput struct {
	ProjectID         uuid.UUID  `json:"project_id"`
	DrawingID         uuid.UUID  `json:"drawing_id"`
	AnnotationType    string     `json:"annotation_type"`
	Text              string     `json:"text"`
	X                 float64    `json:"x"`
	Y                 float64    `json:"y"`
	Width             float64    `json:"width"`
	Height            float64    `json:"height"`
	Rotation          float64    `json:"rotation"`
	LinkedObjectID    *uuid.UUID `json:"linked_object_id"`
	LinkedProductID   *uuid.UUID `json:"linked_product_id"`
	LinkedQuoteItemID *uuid.UUID `json:"linked_quote_item_id"`
	ExportToPDF       *bool      `json:"export_to_pdf"`
	ShowInContract    *bool      `json:"show_in_contract"`
}

func (h BusinessHandler) CreateDrawingAnnotation(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	var input drawingAnnotationInput
	if !bindJSON(c, &input) {
		return
	}
	if !normalizeAnnotationInput(c, &input) {
		return
	}
	drawing, err := h.resolveDrawingForAnnotation(c, a, input.ProjectID, input.DrawingID)
	if err != nil {
		writeDBError(c, err, "drawing not found")
		return
	}
	item, err := h.insertDrawingAnnotation(c, a, drawing, input)
	if err != nil {
		writeDBError(c, err, "drawing annotation not found")
		return
	}
	writeAudit(h.db, c, a, "drawing_annotations.create", "drawing_annotation", item.ID, gin.H{"project_id": item.ProjectID})
	c.JSON(http.StatusCreated, item)
}

func (h BusinessHandler) UpdateDrawingAnnotation(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var input drawingAnnotationInput
	if !bindJSON(c, &input) {
		return
	}
	if !normalizeAnnotationInput(c, &input) {
		return
	}
	exportToPDF := true
	if input.ExportToPDF != nil {
		exportToPDF = *input.ExportToPDF
	}
	showInContract := true
	if input.ShowInContract != nil {
		showInContract = *input.ShowInContract
	}
	var item drawingAnnotationPayload
	err := h.db.QueryRow(c.Request.Context(), `
		UPDATE drawing_annotations
		SET annotation_type=$3, text=$4, x=$5, y=$6, width=$7, height=$8, rotation=$9,
		    linked_object_id=(CASE WHEN $10::uuid IS NULL THEN NULL ELSE (SELECT id FROM drawing_objects WHERE company_id=$1 AND id=$10 AND deleted_at IS NULL) END),
		    linked_product_id=(CASE WHEN $11::uuid IS NULL THEN NULL ELSE (SELECT id FROM products WHERE company_id=$1 AND id=$11 AND deleted_at IS NULL) END),
		    linked_quote_item_id=$12, export_to_pdf=$13, show_in_contract=$14, updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, project_id, drawing_id, annotation_type, text,
		          x::float8, y::float8, width::float8, height::float8, rotation::float8,
		          COALESCE(linked_object_id::text, ''), COALESCE(linked_product_id::text, ''), COALESCE(linked_quote_item_id::text, ''),
		          export_to_pdf, show_in_contract, created_at, updated_at
	`, a.CompanyID, id, input.AnnotationType, input.Text, input.X, input.Y, input.Width, input.Height, input.Rotation,
		input.LinkedObjectID, input.LinkedProductID, input.LinkedQuoteItemID, exportToPDF, showInContract).Scan(
		&item.ID, &item.ProjectID, &item.DrawingID, &item.AnnotationType, &item.Text,
		&item.X, &item.Y, &item.Width, &item.Height, &item.Rotation,
		uuidTextScanner(&item.LinkedObjectID), uuidTextScanner(&item.LinkedProductID), uuidTextScanner(&item.LinkedQuoteItemID),
		&item.ExportToPDF, &item.ShowInContract, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		writeDBError(c, err, "drawing annotation not found")
		return
	}
	writeAudit(h.db, c, a, "drawing_annotations.update", "drawing_annotation", item.ID, gin.H{"project_id": item.ProjectID})
	c.JSON(http.StatusOK, item)
}

func (h BusinessHandler) DeleteDrawingAnnotation(c *gin.Context) {
	a, ok := currentActor(c)
	if !ok {
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	tag, err := h.db.Exec(c.Request.Context(), `
		UPDATE drawing_annotations
		SET deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, a.CompanyID, id)
	if err != nil {
		writeDBError(c, err, "drawing annotation not found")
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "drawing annotation not found"})
		return
	}
	writeAudit(h.db, c, a, "drawing_annotations.delete", "drawing_annotation", id, nil)
	c.Status(http.StatusNoContent)
}

func (h BusinessHandler) ensureDrawing(c *gin.Context, a actor, projectID uuid.UUID) (drawingPayload, error) {
	var drawing drawingPayload
	err := h.db.QueryRow(c.Request.Context(), `
		INSERT INTO drawings (company_id, project_id, created_by)
		SELECT $1, p.id, $3
		FROM projects p
		WHERE p.company_id=$1 AND p.id=$2 AND p.deleted_at IS NULL
		ON CONFLICT (company_id, project_id) DO UPDATE SET updated_at=drawings.updated_at
		RETURNING id, project_id, COALESCE(drawing_file_asset_id::text, ''), COALESCE(preview_file_asset_id::text, ''),
		          canvas_width::float8, canvas_height::float8, status, created_at, updated_at
	`, a.CompanyID, projectID, a.UserID).Scan(
		&drawing.ID, &drawing.ProjectID, uuidTextScanner(&drawing.DrawingFileAssetID), uuidTextScanner(&drawing.PreviewFileAssetID),
		&drawing.CanvasWidth, &drawing.CanvasHeight, &drawing.Status, &drawing.CreatedAt, &drawing.UpdatedAt,
	)
	return drawing, err
}

func (h BusinessHandler) writeDrawingResponse(c *gin.Context, a actor, drawing drawingPayload) {
	objects, err := h.listDrawingObjects(c, a.CompanyID, drawing.ID)
	if err != nil {
		writeDBError(c, err, "drawing objects not found")
		return
	}
	annotations, err := h.listDrawingAnnotations(c, a.CompanyID, drawing.ID)
	if err != nil {
		writeDBError(c, err, "drawing annotations not found")
		return
	}
	c.JSON(http.StatusOK, drawingResponse{Drawing: drawing, Objects: objects, Annotations: annotations})
}

func (h BusinessHandler) resolveDrawingForObject(c *gin.Context, a actor, projectID uuid.UUID, drawingID uuid.UUID) (drawingPayload, error) {
	if projectID != uuid.Nil {
		return h.ensureDrawing(c, a, projectID)
	}
	var drawing drawingPayload
	err := h.db.QueryRow(c.Request.Context(), `
		SELECT id, project_id, COALESCE(drawing_file_asset_id::text, ''), COALESCE(preview_file_asset_id::text, ''),
		       canvas_width::float8, canvas_height::float8, status, created_at, updated_at
		FROM drawings
		WHERE company_id=$1 AND id=$2
	`, a.CompanyID, drawingID).Scan(
		&drawing.ID, &drawing.ProjectID, uuidTextScanner(&drawing.DrawingFileAssetID), uuidTextScanner(&drawing.PreviewFileAssetID),
		&drawing.CanvasWidth, &drawing.CanvasHeight, &drawing.Status, &drawing.CreatedAt, &drawing.UpdatedAt,
	)
	return drawing, err
}

func (h BusinessHandler) resolveDrawingForAnnotation(c *gin.Context, a actor, projectID uuid.UUID, drawingID uuid.UUID) (drawingPayload, error) {
	return h.resolveDrawingForObject(c, a, projectID, drawingID)
}

func (h BusinessHandler) insertDrawingObject(c *gin.Context, a actor, drawing drawingPayload, input drawingObjectInput) (drawingObjectPayload, error) {
	isQuoteEnabled := true
	if input.IsQuoteEnabled != nil {
		isQuoteEnabled = *input.IsQuoteEnabled
	}
	isContractVisible := true
	if input.IsContractVisible != nil {
		isContractVisible = *input.IsContractVisible
	}
	var item drawingObjectPayload
	err := h.db.QueryRow(c.Request.Context(), `
		INSERT INTO drawing_objects (
			company_id, project_id, drawing_id, object_type, product_id, service_id, category_id,
			x, y, width, height, rotation, quantity, unit, discount_amount, installation_fee, notes,
			is_quote_enabled, is_contract_visible, created_by
		)
		VALUES (
			$1, $2, $3, $4,
			(CASE WHEN $5::uuid IS NULL THEN NULL ELSE (SELECT id FROM products WHERE company_id=$1 AND id=$5 AND deleted_at IS NULL) END),
			(CASE WHEN $6::uuid IS NULL THEN NULL ELSE (SELECT id FROM products WHERE company_id=$1 AND id=$6 AND deleted_at IS NULL) END),
			(CASE WHEN $7::uuid IS NULL THEN NULL ELSE (SELECT id FROM product_categories WHERE company_id=$1 AND id=$7 AND deleted_at IS NULL) END),
			$8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20
		)
		RETURNING id, project_id, drawing_id, object_type,
		          COALESCE(product_id::text, ''), COALESCE(service_id::text, ''), COALESCE(category_id::text, ''),
		          x::float8, y::float8, width::float8, height::float8, rotation::float8, quantity::float8, unit,
		          discount_amount::float8, installation_fee::float8, COALESCE(notes, ''),
		          is_quote_enabled, is_contract_visible, status, created_at, updated_at
	`, a.CompanyID, drawing.ProjectID, drawing.ID, input.ObjectType, input.ProductID, input.ServiceID, input.CategoryID,
		input.X, input.Y, input.Width, input.Height, input.Rotation, input.Quantity, input.Unit,
		input.DiscountAmount, input.InstallationFee, input.Notes, isQuoteEnabled, isContractVisible, a.UserID).Scan(
		&item.ID, &item.ProjectID, &item.DrawingID, &item.ObjectType,
		uuidTextScanner(&item.ProductID), uuidTextScanner(&item.ServiceID), uuidTextScanner(&item.CategoryID),
		&item.X, &item.Y, &item.Width, &item.Height, &item.Rotation, &item.Quantity, &item.Unit,
		&item.DiscountAmount, &item.InstallationFee, &item.Notes,
		&item.IsQuoteEnabled, &item.IsContractVisible, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, err
}

func (h BusinessHandler) insertDrawingAnnotation(c *gin.Context, a actor, drawing drawingPayload, input drawingAnnotationInput) (drawingAnnotationPayload, error) {
	exportToPDF := true
	if input.ExportToPDF != nil {
		exportToPDF = *input.ExportToPDF
	}
	showInContract := true
	if input.ShowInContract != nil {
		showInContract = *input.ShowInContract
	}
	var item drawingAnnotationPayload
	err := h.db.QueryRow(c.Request.Context(), `
		INSERT INTO drawing_annotations (
			company_id, project_id, drawing_id, annotation_type, text, x, y, width, height, rotation,
			linked_object_id, linked_product_id, linked_quote_item_id, export_to_pdf, show_in_contract, created_by
		)
		VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
			(CASE WHEN $11::uuid IS NULL THEN NULL ELSE (SELECT id FROM drawing_objects WHERE company_id=$1 AND id=$11 AND deleted_at IS NULL) END),
			(CASE WHEN $12::uuid IS NULL THEN NULL ELSE (SELECT id FROM products WHERE company_id=$1 AND id=$12 AND deleted_at IS NULL) END),
			$13, $14, $15, $16
		)
		RETURNING id, project_id, drawing_id, annotation_type, text,
		          x::float8, y::float8, width::float8, height::float8, rotation::float8,
		          COALESCE(linked_object_id::text, ''), COALESCE(linked_product_id::text, ''), COALESCE(linked_quote_item_id::text, ''),
		          export_to_pdf, show_in_contract, created_at, updated_at
	`, a.CompanyID, drawing.ProjectID, drawing.ID, input.AnnotationType, input.Text,
		input.X, input.Y, input.Width, input.Height, input.Rotation,
		input.LinkedObjectID, input.LinkedProductID, input.LinkedQuoteItemID,
		exportToPDF, showInContract, a.UserID).Scan(
		&item.ID, &item.ProjectID, &item.DrawingID, &item.AnnotationType, &item.Text,
		&item.X, &item.Y, &item.Width, &item.Height, &item.Rotation,
		uuidTextScanner(&item.LinkedObjectID), uuidTextScanner(&item.LinkedProductID), uuidTextScanner(&item.LinkedQuoteItemID),
		&item.ExportToPDF, &item.ShowInContract, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, err
}

func (h BusinessHandler) listDrawingObjects(c *gin.Context, companyID uuid.UUID, drawingID uuid.UUID) ([]drawingObjectPayload, error) {
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id, project_id, drawing_id, object_type,
		       COALESCE(product_id::text, ''), COALESCE(service_id::text, ''), COALESCE(category_id::text, ''),
		       x::float8, y::float8, width::float8, height::float8, rotation::float8, quantity::float8, unit,
		       discount_amount::float8, installation_fee::float8, COALESCE(notes, ''),
		       is_quote_enabled, is_contract_visible, status, created_at, updated_at
		FROM drawing_objects
		WHERE company_id=$1 AND drawing_id=$2 AND deleted_at IS NULL AND status <> 'deleted'
		ORDER BY created_at ASC
	`, companyID, drawingID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]drawingObjectPayload, 0)
	for rows.Next() {
		var item drawingObjectPayload
		if err := rows.Scan(
			&item.ID, &item.ProjectID, &item.DrawingID, &item.ObjectType,
			uuidTextScanner(&item.ProductID), uuidTextScanner(&item.ServiceID), uuidTextScanner(&item.CategoryID),
			&item.X, &item.Y, &item.Width, &item.Height, &item.Rotation, &item.Quantity, &item.Unit,
			&item.DiscountAmount, &item.InstallationFee, &item.Notes,
			&item.IsQuoteEnabled, &item.IsContractVisible, &item.Status, &item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (h BusinessHandler) listDrawingAnnotations(c *gin.Context, companyID uuid.UUID, drawingID uuid.UUID) ([]drawingAnnotationPayload, error) {
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id, project_id, drawing_id, annotation_type, text,
		       x::float8, y::float8, width::float8, height::float8, rotation::float8,
		       COALESCE(linked_object_id::text, ''), COALESCE(linked_product_id::text, ''), COALESCE(linked_quote_item_id::text, ''),
		       export_to_pdf, show_in_contract, created_at, updated_at
		FROM drawing_annotations
		WHERE company_id=$1 AND drawing_id=$2 AND deleted_at IS NULL
		ORDER BY created_at ASC
	`, companyID, drawingID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]drawingAnnotationPayload, 0)
	for rows.Next() {
		var item drawingAnnotationPayload
		if err := rows.Scan(
			&item.ID, &item.ProjectID, &item.DrawingID, &item.AnnotationType, &item.Text,
			&item.X, &item.Y, &item.Width, &item.Height, &item.Rotation,
			uuidTextScanner(&item.LinkedObjectID), uuidTextScanner(&item.LinkedProductID), uuidTextScanner(&item.LinkedQuoteItemID),
			&item.ExportToPDF, &item.ShowInContract, &item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func normalizeDrawingObjectInput(c *gin.Context, input *drawingObjectInput) bool {
	input.ObjectType = strings.TrimSpace(strings.ToLower(input.ObjectType))
	if input.ObjectType == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "object_type is required"})
		return false
	}
	input.X = clampUnit(input.X, 0.45)
	input.Y = clampUnit(input.Y, 0.45)
	input.Width = clampUnit(input.Width, 0.18)
	input.Height = clampUnit(input.Height, 0.12)
	if input.Quantity <= 0 {
		input.Quantity = 1
	}
	input.Unit = strings.TrimSpace(input.Unit)
	if input.Unit == "" {
		input.Unit = "each"
	}
	input.Notes = strings.TrimSpace(input.Notes)
	if input.DiscountAmount < 0 {
		input.DiscountAmount = 0
	}
	if input.InstallationFee < 0 {
		input.InstallationFee = 0
	}
	return true
}

func normalizeAnnotationInput(c *gin.Context, input *drawingAnnotationInput) bool {
	input.AnnotationType = strings.TrimSpace(strings.ToLower(input.AnnotationType))
	if input.AnnotationType == "" {
		input.AnnotationType = "note"
	}
	input.Text = strings.TrimSpace(input.Text)
	if input.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "annotation text is required"})
		return false
	}
	input.X = clampUnit(input.X, 0.5)
	input.Y = clampUnit(input.Y, 0.25)
	input.Width = clampUnit(input.Width, 0.2)
	input.Height = clampUnit(input.Height, 0.07)
	return true
}

type uuidScanner struct {
	target **uuid.UUID
}

func uuidTextScanner(target **uuid.UUID) *uuidScanner {
	return &uuidScanner{target: target}
}

func (s *uuidScanner) Scan(value any) error {
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
		text = fmt.Sprint(v)
	}
	*s.target = optionalUUID(text)
	return nil
}
