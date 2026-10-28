
-- Migration 018
-- Automatically enqueue notifications for new inquiries
-- Northstar Home Services

CREATE OR REPLACE FUNCTION public.northstar_enqueue_inquiry_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.notification_outbox (
        inquiry_id,
        notification_type,
        status
    )
    VALUES (
        NEW.inquiry_id,
        'team_assignment',
        'pending'
    )
    ON CONFLICT (inquiry_id, notification_type)
    DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_northstar_enqueue_inquiry_notification
AFTER INSERT ON public.inquiries
FOR EACH ROW
EXECUTE FUNCTION public.northstar_enqueue_inquiry_notification();
