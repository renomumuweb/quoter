CREATE TABLE project_estimates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    renovation_type text NOT NULL DEFAULT 'custom_project',
    categories jsonb NOT NULL DEFAULT '[]'::jsonb,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'ready', 'quoted', 'archived')),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    UNIQUE (company_id, project_id)
);

CREATE INDEX idx_project_estimates_company_updated
    ON project_estimates (company_id, updated_at DESC)
    WHERE deleted_at IS NULL;

ALTER TABLE quote_items
    ADD COLUMN source_kind text NOT NULL DEFAULT 'drawing_object',
    ADD COLUMN source_estimate_item_id uuid,
    ADD COLUMN room_snapshot text,
    ADD COLUMN scope_snapshot text,
    ADD COLUMN material_snapshot text,
    ADD COLUMN supplied_by_snapshot text,
    ADD COLUMN pricing_status text NOT NULL DEFAULT 'pending'
        CHECK (pricing_status IN ('pending', 'priced', 'included', 'excluded'));

CREATE INDEX idx_quote_items_source_estimate_item
    ON quote_items (company_id, source_estimate_item_id)
    WHERE source_estimate_item_id IS NOT NULL;
