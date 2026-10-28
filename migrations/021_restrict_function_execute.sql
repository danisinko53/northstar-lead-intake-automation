BEGIN;

REVOKE EXECUTE ON FUNCTION
    public.northstar_save_lead(jsonb)
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    public.northstar_recover_stale_notifications()
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
    public.northstar_enqueue_inquiry_notification()
FROM PUBLIC;

-- Preserve application access explicitly.
GRANT EXECUTE ON FUNCTION
    public.northstar_save_lead(jsonb)
TO northstar_app;

GRANT EXECUTE ON FUNCTION
    public.northstar_recover_stale_notifications()
TO northstar_app;

GRANT EXECUTE ON FUNCTION
    public.northstar_enqueue_inquiry_notification()
TO northstar_app;


ALTER DEFAULT PRIVILEGES FOR ROLE northstar
IN SCHEMA public
REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

COMMIT;
