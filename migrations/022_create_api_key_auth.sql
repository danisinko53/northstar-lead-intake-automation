
BEGIN;

CREATE TABLE public.api_auth_keys (
    key_id TEXT PRIMARY KEY,
    key_salt TEXT NOT NULL,
    key_hash BYTEA NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

REVOKE ALL ON TABLE public.api_auth_keys FROM PUBLIC;
REVOKE ALL ON TABLE public.api_auth_keys FROM northstar_app;

CREATE FUNCTION public.northstar_verify_api_key(p_key TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
    SELECT COALESCE(
        p_key IS NOT NULL
        AND LENGTH(p_key) > 0
        AND EXISTS (
            SELECT 1
            FROM public.api_auth_keys k
            WHERE k.is_active = TRUE
              AND k.key_hash = pg_catalog.sha256(
                  pg_catalog.convert_to(k.key_salt || p_key, 'UTF8')
              )
        ),
        FALSE
    );
$$;

REVOKE ALL ON FUNCTION public.northstar_verify_api_key(TEXT)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.northstar_verify_api_key(TEXT)
TO northstar_app;

COMMIT;
