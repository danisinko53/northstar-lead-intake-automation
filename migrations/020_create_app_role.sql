
-- Migration 020
-- Restricted application database role
-- Northstar Home Services
--
-- Run as the database administrator after migrations 001-019.
-- The password must be configured separately.
-- Never store database passwords in migrations.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'northstar_app'
    ) THEN
        CREATE ROLE northstar_app
            LOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS
            PASSWORD NULL;
    END IF;
END;
$$;

ALTER ROLE northstar_app
    WITH LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

GRANT CONNECT ON DATABASE northstar_crm
    TO northstar_app;

GRANT USAGE ON SCHEMA public
    TO northstar_app;

GRANT SELECT, INSERT
    ON public.customers, public.inquiries
    TO northstar_app;

GRANT SELECT
    ON public.service_routing
    TO northstar_app;

GRANT INSERT
    ON public.audit_events
    TO northstar_app;

GRANT SELECT (event_id)
    ON public.audit_events
    TO northstar_app;

GRANT SELECT, INSERT, UPDATE
    ON public.notification_outbox
    TO northstar_app;

GRANT EXECUTE
    ON FUNCTION public.northstar_save_lead(jsonb)
    TO northstar_app;

GRANT EXECUTE
    ON FUNCTION public.northstar_recover_stale_notifications()
    TO northstar_app;

GRANT EXECUTE
    ON FUNCTION public.northstar_enqueue_inquiry_notification()
    TO northstar_app;
