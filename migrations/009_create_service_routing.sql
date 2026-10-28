
CREATE TABLE public.service_routing (
    service_type TEXT PRIMARY KEY,
    assigned_team TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO public.service_routing (
    service_type,
    assigned_team
)
VALUES
    ('plumbing', 'PLUMBING_TEAM'),
    ('electrical', 'ELECTRICAL_TEAM'),
    ('hvac', 'HVAC_TEAM'),
    ('general_repair', 'GENERAL_TEAM');
