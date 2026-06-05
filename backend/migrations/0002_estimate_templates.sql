CREATE TABLE estimate_templates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    source_project_id uuid REFERENCES projects(id) ON DELETE SET NULL,
    name text NOT NULL,
    renovation_type text NOT NULL DEFAULT 'custom_project',
    categories jsonb NOT NULL DEFAULT '[]'::jsonb,
    active boolean NOT NULL DEFAULT true,
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE UNIQUE INDEX idx_estimate_templates_company_name_active
    ON estimate_templates (company_id, lower(name))
    WHERE deleted_at IS NULL;

CREATE INDEX idx_estimate_templates_company_updated
    ON estimate_templates (company_id, updated_at DESC)
    WHERE deleted_at IS NULL;
