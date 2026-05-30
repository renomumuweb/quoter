CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE companies (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    legal_name text,
    email text,
    phone text,
    address text,
    tax_rate numeric(6,5) NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    email citext NOT NULL,
    name text NOT NULL,
    password_hash text NOT NULL,
    role text NOT NULL DEFAULT 'sales' CHECK (role IN ('admin', 'sales', 'designer')),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'invited', 'disabled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    UNIQUE (email)
);

CREATE TABLE user_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash text NOT NULL UNIQUE,
    user_agent text,
    ip_address inet,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    rotated_to_session_id uuid REFERENCES user_sessions(id),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE customers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name text NOT NULL,
    phone text,
    email text,
    address text,
    notes text,
    status text NOT NULL DEFAULT 'active',
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE projects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    title text NOT NULL,
    room_type text NOT NULL DEFAULT 'bathroom',
    status text NOT NULL DEFAULT 'draft',
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE file_assets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    owner_type text,
    owner_id uuid,
    bucket text NOT NULL,
    object_key text NOT NULL,
    original_filename text,
    mime_type text,
    size_bytes bigint,
    checksum text,
    status text NOT NULL DEFAULT 'active',
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (bucket, object_key)
);

CREATE TABLE drawings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    drawing_file_asset_id uuid REFERENCES file_assets(id),
    preview_file_asset_id uuid REFERENCES file_assets(id),
    canvas_width numeric(10,2) NOT NULL DEFAULT 1,
    canvas_height numeric(10,2) NOT NULL DEFAULT 1,
    status text NOT NULL DEFAULT 'draft',
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (company_id, project_id)
);

CREATE TABLE brands (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name text NOT NULL,
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    UNIQUE (company_id, name)
);

CREATE TABLE product_categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    parent_id uuid REFERENCES product_categories(id),
    name text NOT NULL,
    kind text NOT NULL DEFAULT 'product' CHECK (kind IN ('product', 'service')),
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    UNIQUE (company_id, name)
);

CREATE TABLE products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    brand_id uuid REFERENCES brands(id),
    category_id uuid NOT NULL REFERENCES product_categories(id),
    name text NOT NULL,
    sku text NOT NULL,
    size text,
    color text,
    material text,
    unit text NOT NULL DEFAULT 'each',
    description text,
    image_url text,
    active boolean NOT NULL DEFAULT true,
    is_service boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    UNIQUE (company_id, sku)
);

CREATE TABLE product_prices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    currency text NOT NULL DEFAULT 'USD',
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (effective_to IS NULL OR effective_to >= effective_from),
    UNIQUE (product_id, effective_from)
);

CREATE TABLE drawing_objects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    drawing_id uuid NOT NULL REFERENCES drawings(id) ON DELETE CASCADE,
    object_type text NOT NULL,
    product_id uuid REFERENCES products(id),
    service_id uuid REFERENCES products(id),
    category_id uuid REFERENCES product_categories(id),
    x numeric(9,6) NOT NULL CHECK (x >= 0 AND x <= 1),
    y numeric(9,6) NOT NULL CHECK (y >= 0 AND y <= 1),
    width numeric(9,6) NOT NULL CHECK (width >= 0 AND width <= 1),
    height numeric(9,6) NOT NULL CHECK (height >= 0 AND height <= 1),
    rotation numeric(8,3) NOT NULL DEFAULT 0,
    quantity numeric(12,2) NOT NULL DEFAULT 1 CHECK (quantity >= 0),
    unit text NOT NULL DEFAULT 'each',
    discount_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    installation_fee numeric(12,2) NOT NULL DEFAULT 0 CHECK (installation_fee >= 0),
    notes text,
    is_quote_enabled boolean NOT NULL DEFAULT true,
    is_contract_visible boolean NOT NULL DEFAULT true,
    status text NOT NULL DEFAULT 'active',
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE drawing_annotations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    drawing_id uuid NOT NULL REFERENCES drawings(id) ON DELETE CASCADE,
    annotation_type text NOT NULL,
    text text NOT NULL,
    x numeric(9,6) NOT NULL CHECK (x >= 0 AND x <= 1),
    y numeric(9,6) NOT NULL CHECK (y >= 0 AND y <= 1),
    width numeric(9,6) NOT NULL CHECK (width >= 0 AND width <= 1),
    height numeric(9,6) NOT NULL CHECK (height >= 0 AND height <= 1),
    rotation numeric(8,3) NOT NULL DEFAULT 0,
    linked_object_id uuid REFERENCES drawing_objects(id),
    linked_product_id uuid REFERENCES products(id),
    linked_quote_item_id uuid,
    export_to_pdf boolean NOT NULL DEFAULT true,
    show_in_contract boolean NOT NULL DEFAULT true,
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE quotes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
    drawing_id uuid REFERENCES drawings(id),
    quote_number text NOT NULL,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'confirmed', 'cancelled')),
    currency text NOT NULL DEFAULT 'USD',
    subtotal numeric(12,2) NOT NULL DEFAULT 0,
    discount_total numeric(12,2) NOT NULL DEFAULT 0,
    tax_rate numeric(6,5) NOT NULL DEFAULT 0,
    tax_total numeric(12,2) NOT NULL DEFAULT 0,
    total numeric(12,2) NOT NULL DEFAULT 0,
    snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    confirmed_at timestamptz,
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    UNIQUE (company_id, quote_number)
);

CREATE TABLE quote_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    quote_id uuid NOT NULL REFERENCES quotes(id) ON DELETE CASCADE,
    product_id uuid REFERENCES products(id),
    source_object_id uuid REFERENCES drawing_objects(id),
    product_name_snapshot text NOT NULL,
    sku_snapshot text,
    brand_snapshot text,
    category_snapshot text,
    unit_snapshot text NOT NULL,
    unit_price_snapshot numeric(12,2) NOT NULL DEFAULT 0,
    quantity numeric(12,2) NOT NULL DEFAULT 1,
    discount_amount numeric(12,2) NOT NULL DEFAULT 0,
    installation_fee numeric(12,2) NOT NULL DEFAULT 0,
    line_total numeric(12,2) NOT NULL DEFAULT 0,
    notes_snapshot text,
    is_contract_visible boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE drawing_annotations
    ADD CONSTRAINT drawing_annotations_linked_quote_item_fk
    FOREIGN KEY (linked_quote_item_id) REFERENCES quote_items(id);

CREATE TABLE contract_templates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name text NOT NULL,
    payment_terms text NOT NULL DEFAULT '',
    delivery_terms text NOT NULL DEFAULT '',
    disclaimer text NOT NULL DEFAULT '',
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    UNIQUE (company_id, name)
);

CREATE TABLE contracts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    quote_id uuid NOT NULL REFERENCES quotes(id) ON DELETE RESTRICT,
    contract_template_id uuid REFERENCES contract_templates(id),
    pdf_file_asset_id uuid REFERENCES file_assets(id),
    contract_number text NOT NULL,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'issued', 'signed', 'cancelled')),
    payment_terms text NOT NULL DEFAULT '',
    delivery_terms text NOT NULL DEFAULT '',
    disclaimer text NOT NULL DEFAULT '',
    snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    issued_at timestamptz,
    signed_at timestamptz,
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    UNIQUE (company_id, contract_number)
);

CREATE TABLE audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    user_id uuid REFERENCES users(id),
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_company_id ON users(company_id);
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_customers_company_id ON customers(company_id);
CREATE INDEX idx_projects_company_customer ON projects(company_id, customer_id);
CREATE INDEX idx_drawings_project ON drawings(company_id, project_id);
CREATE INDEX idx_drawing_objects_drawing ON drawing_objects(company_id, drawing_id);
CREATE INDEX idx_drawing_annotations_drawing ON drawing_annotations(company_id, drawing_id);
CREATE INDEX idx_products_company_category ON products(company_id, category_id);
CREATE INDEX idx_product_prices_product_dates ON product_prices(product_id, effective_from, effective_to);
CREATE INDEX idx_quotes_project ON quotes(company_id, project_id);
CREATE INDEX idx_quote_items_quote ON quote_items(company_id, quote_id);
CREATE INDEX idx_contracts_quote ON contracts(company_id, quote_id);
CREATE INDEX idx_file_assets_owner ON file_assets(company_id, owner_type, owner_id);
CREATE INDEX idx_audit_logs_company_created ON audit_logs(company_id, created_at DESC);
