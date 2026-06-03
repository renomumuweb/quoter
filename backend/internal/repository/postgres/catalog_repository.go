package postgres

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"quoter/backend/internal/domain/catalog"
)

type CatalogRepository struct {
	db *pgxpool.Pool
}

func NewCatalogRepository(db *pgxpool.Pool) *CatalogRepository {
	return &CatalogRepository{db: db}
}

func (r *CatalogRepository) ListBrands(ctx context.Context, companyID uuid.UUID) ([]catalog.Brand, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, name, status, created_at, updated_at
		FROM brands
		WHERE company_id=$1 AND deleted_at IS NULL
		ORDER BY name ASC
	`, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]catalog.Brand, 0)
	for rows.Next() {
		var item catalog.Brand
		if err := rows.Scan(&item.ID, &item.Name, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *CatalogRepository) CreateBrand(ctx context.Context, companyID uuid.UUID, input catalog.BrandInput) (catalog.Brand, error) {
	var item catalog.Brand
	err := r.db.QueryRow(ctx, `
		INSERT INTO brands (company_id, name)
		VALUES ($1, $2)
		RETURNING id, name, status, created_at, updated_at
	`, companyID, input.Name).Scan(&item.ID, &item.Name, &item.Status, &item.CreatedAt, &item.UpdatedAt)
	return item, err
}

func (r *CatalogRepository) UpdateBrand(ctx context.Context, companyID uuid.UUID, id uuid.UUID, input catalog.BrandInput) (catalog.Brand, error) {
	var item catalog.Brand
	err := r.db.QueryRow(ctx, `
		UPDATE brands
		SET name=$3, updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, name, status, created_at, updated_at
	`, companyID, id, input.Name).Scan(&item.ID, &item.Name, &item.Status, &item.CreatedAt, &item.UpdatedAt)
	return item, err
}

func (r *CatalogRepository) DeleteBrand(ctx context.Context, companyID uuid.UUID, id uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE brands
		SET status='deleted', deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, companyID, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *CatalogRepository) ListCategories(ctx context.Context, companyID uuid.UUID) ([]catalog.Category, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, COALESCE(parent_id::text, ''), name, kind, status, created_at, updated_at
		FROM product_categories
		WHERE company_id=$1 AND deleted_at IS NULL
		ORDER BY kind ASC, name ASC
	`, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]catalog.Category, 0)
	for rows.Next() {
		var item catalog.Category
		if err := rows.Scan(&item.ID, uuidTextScanner(&item.ParentID), &item.Name, &item.Kind, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *CatalogRepository) CreateCategory(ctx context.Context, companyID uuid.UUID, input catalog.CategoryInput) (catalog.Category, error) {
	var item catalog.Category
	err := r.db.QueryRow(ctx, `
		INSERT INTO product_categories (company_id, parent_id, name, kind)
		VALUES (
			$1,
			(CASE WHEN $2::uuid IS NULL THEN NULL ELSE (SELECT id FROM product_categories WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL) END),
			$3, $4
		)
		RETURNING id, COALESCE(parent_id::text, ''), name, kind, status, created_at, updated_at
	`, companyID, input.ParentID, input.Name, input.Kind).Scan(
		&item.ID, uuidTextScanner(&item.ParentID), &item.Name, &item.Kind, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, err
}

func (r *CatalogRepository) UpdateCategory(ctx context.Context, companyID uuid.UUID, id uuid.UUID, input catalog.CategoryInput) (catalog.Category, error) {
	var item catalog.Category
	err := r.db.QueryRow(ctx, `
		UPDATE product_categories
		SET parent_id=(CASE WHEN $3::uuid IS NULL THEN NULL ELSE (SELECT id FROM product_categories WHERE company_id=$1 AND id=$3 AND deleted_at IS NULL) END),
		    name=$4, kind=$5, updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, COALESCE(parent_id::text, ''), name, kind, status, created_at, updated_at
	`, companyID, id, input.ParentID, input.Name, input.Kind).Scan(
		&item.ID, uuidTextScanner(&item.ParentID), &item.Name, &item.Kind, &item.Status, &item.CreatedAt, &item.UpdatedAt,
	)
	return item, err
}

func (r *CatalogRepository) DeleteCategory(ctx context.Context, companyID uuid.UUID, id uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE product_categories
		SET status='deleted', deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, companyID, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *CatalogRepository) ListProducts(ctx context.Context, companyID uuid.UUID, filter catalog.ProductFilter) ([]catalog.Product, error) {
	args := []any{companyID}
	query := productSelectSQL() + `
		WHERE p.company_id=$1 AND p.deleted_at IS NULL
	`
	if filter.ActiveOnly {
		query += ` AND p.active=true`
	}
	if strings.TrimSpace(filter.Query) != "" {
		args = append(args, "%"+strings.ToLower(strings.TrimSpace(filter.Query))+"%")
		position := "$" + strconv.Itoa(len(args))
		query += ` AND (lower(p.name) LIKE ` + position + ` OR lower(p.sku) LIKE ` + position + ` OR lower(COALESCE(b.name, '')) LIKE ` + position + ` OR lower(pc.name) LIKE ` + position + `)`
	}
	if filter.CategoryID != nil {
		args = append(args, *filter.CategoryID)
		query += ` AND p.category_id=$` + strconv.Itoa(len(args))
	}
	if filter.BrandID != nil {
		args = append(args, *filter.BrandID)
		query += ` AND p.brand_id=$` + strconv.Itoa(len(args))
	}
	query += ` ORDER BY pc.name ASC, p.name ASC`

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]catalog.Product, 0)
	for rows.Next() {
		item, err := scanProduct(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *CatalogRepository) GetProduct(ctx context.Context, companyID uuid.UUID, id uuid.UUID) (catalog.Product, error) {
	rows, err := r.db.Query(ctx, productSelectSQL()+`
		WHERE p.company_id=$1 AND p.id=$2 AND p.deleted_at IS NULL
	`, companyID, id)
	if err != nil {
		return catalog.Product{}, err
	}
	defer rows.Close()
	if !rows.Next() {
		return catalog.Product{}, pgx.ErrNoRows
	}
	item, err := scanProduct(rows)
	if err != nil {
		return catalog.Product{}, err
	}
	return item, rows.Err()
}

func (r *CatalogRepository) CreateProduct(ctx context.Context, companyID uuid.UUID, input catalog.ProductInput) (catalog.Product, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return catalog.Product{}, err
	}
	defer tx.Rollback(ctx)

	var id uuid.UUID
	err = tx.QueryRow(ctx, `
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
	`, companyID, input.BrandID, input.CategoryID, input.Name, input.SKU, input.Size, input.Color,
		input.Material, input.Unit, input.Description, input.ImageURL, input.ActiveValue(), input.IsServiceValue()).Scan(&id)
	if err != nil {
		return catalog.Product{}, err
	}
	if err := upsertCurrentPrice(ctx, tx, companyID, id, input); err != nil {
		return catalog.Product{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return catalog.Product{}, err
	}
	return r.GetProduct(ctx, companyID, id)
}

func (r *CatalogRepository) UpdateProduct(ctx context.Context, companyID uuid.UUID, id uuid.UUID, input catalog.ProductInput) (catalog.Product, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return catalog.Product{}, err
	}
	defer tx.Rollback(ctx)

	tag, err := tx.Exec(ctx, `
		UPDATE products p
		SET brand_id=(CASE WHEN $3::uuid IS NULL THEN NULL ELSE (SELECT id FROM brands WHERE company_id=$1 AND id=$3 AND deleted_at IS NULL) END),
		    category_id=c.id, name=$5, sku=$6, size=$7, color=$8, material=$9, unit=$10,
		    description=$11, image_url=$12, active=$13, is_service=$14, updated_at=now()
		FROM product_categories c
		WHERE p.company_id=$1 AND p.id=$2 AND p.deleted_at IS NULL
		  AND c.company_id=$1 AND c.id=$4 AND c.deleted_at IS NULL
	`, companyID, id, input.BrandID, input.CategoryID, input.Name, input.SKU, input.Size,
		input.Color, input.Material, input.Unit, input.Description, input.ImageURL, input.ActiveValue(), input.IsServiceValue())
	if err != nil {
		return catalog.Product{}, err
	}
	if tag.RowsAffected() == 0 {
		return catalog.Product{}, pgx.ErrNoRows
	}
	if err := upsertCurrentPrice(ctx, tx, companyID, id, input); err != nil {
		return catalog.Product{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return catalog.Product{}, err
	}
	return r.GetProduct(ctx, companyID, id)
}

func (r *CatalogRepository) DeleteProduct(ctx context.Context, companyID uuid.UUID, id uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE products
		SET status='deleted', active=false, deleted_at=now(), updated_at=now()
		WHERE company_id=$1 AND id=$2 AND deleted_at IS NULL
	`, companyID, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

type priceTx interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
}

func upsertCurrentPrice(ctx context.Context, tx priceTx, companyID uuid.UUID, productID uuid.UUID, input catalog.ProductInput) error {
	if input.CurrentPrice == nil {
		return nil
	}
	_, err := tx.Exec(ctx, `
		INSERT INTO product_prices (company_id, product_id, currency, unit_price, effective_from)
		VALUES ($1, $2, $3, $4, CURRENT_DATE)
		ON CONFLICT (product_id, effective_from)
		DO UPDATE SET unit_price=EXCLUDED.unit_price, currency=EXCLUDED.currency
	`, companyID, productID, input.Currency, *input.CurrentPrice)
	return err
}

func productSelectSQL() string {
	return `
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
	`
}

func scanProduct(row interface{ Scan(...any) error }) (catalog.Product, error) {
	var item catalog.Product
	var priceText string
	err := row.Scan(
		&item.ID, uuidTextScanner(&item.BrandID), &item.Brand, &item.CategoryID, &item.Category, &item.CategoryKind,
		&item.Name, &item.SKU, stringPtrScanner(&item.Size), stringPtrScanner(&item.Color), stringPtrScanner(&item.Material), &item.Unit,
		stringPtrScanner(&item.Description), stringPtrScanner(&item.ImageURL), &item.Active, &item.IsService, &item.Status,
		&item.CreatedAt, &item.UpdatedAt, uuidTextScanner(&item.CurrentPriceID), &item.Currency, &priceText,
	)
	if price, ok := parseNumericString(priceText); ok {
		item.CurrentPrice = &price
	}
	return item, err
}

type optionalUUIDScanner struct {
	target **uuid.UUID
}

func uuidTextScanner(target **uuid.UUID) *optionalUUIDScanner {
	return &optionalUUIDScanner{target: target}
}

func (s *optionalUUIDScanner) Scan(value any) error {
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

type optionalStringScanner struct {
	target **string
}

func stringPtrScanner(target **string) *optionalStringScanner {
	return &optionalStringScanner{target: target}
}

func (s *optionalStringScanner) Scan(value any) error {
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
	text = strings.TrimSpace(text)
	if text == "" {
		*s.target = nil
		return nil
	}
	*s.target = &text
	return nil
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

func parseNumericString(value string) (float64, bool) {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0, false
	}
	parsed, err := strconv.ParseFloat(value, 64)
	return parsed, err == nil
}
