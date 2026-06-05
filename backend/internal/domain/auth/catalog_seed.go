package auth

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func seedDefaultCatalog(ctx context.Context, tx pgx.Tx, companyID uuid.UUID) error {
	var brandID uuid.UUID
	if err := tx.QueryRow(ctx, `
		INSERT INTO brands (company_id, name)
		VALUES ($1, 'Quoter Demo')
		ON CONFLICT (company_id, name) DO UPDATE SET name = EXCLUDED.name
		RETURNING id
	`, companyID).Scan(&brandID); err != nil {
		return err
	}

	categoryIDs := map[string]uuid.UUID{}
	for _, name := range []string{"Vanity", "Toilet", "Shower", "Tile", "Install Service", "Demo Service"} {
		var id uuid.UUID
		if err := tx.QueryRow(ctx, `
			INSERT INTO product_categories (company_id, name, kind)
			VALUES ($1, $2, CASE WHEN $2 LIKE '%Service' THEN 'service' ELSE 'product' END)
			ON CONFLICT (company_id, name) DO UPDATE SET kind = EXCLUDED.kind
			RETURNING id
		`, companyID, name).Scan(&id); err != nil {
			return err
		}
		categoryIDs[name] = id
	}

	products := []struct {
		category string
		name     string
		sku      string
		size     string
		color    string
		material string
		unit     string
		price    string
		service  bool
	}{
		{"Vanity", "60 inch white vanity", "VAN-60-WHITE-001", "60 inch", "white", "painted plywood cabinet / ceramic top", "each", "1299.00", false},
		{"Toilet", "Comfort height toilet", "TOI-COMFORT-001", "elongated", "white", "vitreous china", "each", "399.00", false},
		{"Shower", "Matte black shower kit", "SHW-MB-001", "standard", "matte black", "tempered glass / brass trim", "each", "899.00", false},
		{"Tile", "12 x 24 porcelain tile", "TILE-1224-POR-001", "12 x 24", "white", "porcelain", "sqft", "4.75", false},
		{"Install Service", "Bathroom basic install package", "SVC-INSTALL-BATH-001", "", "", "labor package", "job", "2500.00", true},
		{"Demo Service", "Tub and tile demolition", "SVC-DEMO-TUB-001", "", "", "labor package", "job", "950.00", true},
	}

	for _, item := range products {
		var productID uuid.UUID
		if err := tx.QueryRow(ctx, `
			INSERT INTO products (
				company_id, brand_id, category_id, name, sku, size, color, material, unit, description, active, is_service
			)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'Seeded demo item', true, $10)
			ON CONFLICT (company_id, sku) DO UPDATE SET
				name = EXCLUDED.name,
				category_id = EXCLUDED.category_id,
				size = EXCLUDED.size,
				color = EXCLUDED.color,
				material = EXCLUDED.material,
				unit = EXCLUDED.unit,
				active = true
			RETURNING id
		`, companyID, brandID, categoryIDs[item.category], item.name, item.sku, item.size, item.color, item.material, item.unit, item.service).Scan(&productID); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO product_prices (company_id, product_id, currency, unit_price, effective_from)
			VALUES ($1, $2, 'USD', $3, CURRENT_DATE)
			ON CONFLICT (product_id, effective_from) DO UPDATE SET unit_price = EXCLUDED.unit_price
		`, companyID, productID, item.price); err != nil {
			return err
		}
	}

	return nil
}
