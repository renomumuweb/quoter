-- Optional demo catalog for local development.
-- New companies created through /auth/register are automatically seeded by the API too.

INSERT INTO companies (id, name, tax_rate)
VALUES ('00000000-0000-0000-0000-000000000001', 'Demo Quoter Company', 0.13)
ON CONFLICT (id) DO NOTHING;

INSERT INTO brands (id, company_id, name)
VALUES ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000001', 'Quoter Demo')
ON CONFLICT (company_id, name) DO NOTHING;

INSERT INTO product_categories (id, company_id, name, kind)
VALUES
  ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000001', 'Vanity', 'product'),
  ('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000001', 'Toilet', 'product'),
  ('00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-000000000001', 'Install Service', 'service')
ON CONFLICT (company_id, name) DO NOTHING;

INSERT INTO products (id, company_id, brand_id, category_id, name, sku, size, color, unit, description, active, is_service)
VALUES
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000201', '60 inch white vanity', 'VAN-60-WHITE-001', '60 inch', 'white', 'each', 'Demo vanity for matcher tests', true, false),
  ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000202', 'Comfort height toilet', 'TOI-COMFORT-001', 'elongated', 'white', 'each', 'Demo toilet', true, false),
  ('00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000203', 'Bathroom basic install package', 'SVC-INSTALL-BATH-001', '', '', 'job', 'Demo install service', true, true)
ON CONFLICT (company_id, sku) DO NOTHING;

INSERT INTO product_prices (company_id, product_id, currency, unit_price, effective_from)
VALUES
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000301', 'USD', 1299.00, CURRENT_DATE),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000302', 'USD', 399.00, CURRENT_DATE),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000303', 'USD', 2500.00, CURRENT_DATE)
ON CONFLICT (product_id, effective_from) DO NOTHING;
