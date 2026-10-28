
-- Migration 019
-- Recover abandoned notification claims
-- Northstar Home Services

CREATE OR REPLACE FUNCTION public.northstar_recover_stale_notifications()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_recovered INTEGER;
BEGIN
    UPDATE public.notification_outbox
    SET
        status = 'failed',
        claimed_at = NULL,
        next_attempt_at = CURRENT_TIMESTAMP,
        last_error_code = 'CLAIM_TIMEOUT'
    WHERE status = 'processing'
      AND claimed_at < CURRENT_TIMESTAMP - INTERVAL '15 minutes';

    GET DIAGNOSTICS v_recovered = ROW_COUNT;

    RETURN v_recovered;
END;
$$;
