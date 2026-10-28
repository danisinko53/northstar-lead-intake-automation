CREATE TABLE public.audit_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    submission_id UUID,
    inquiry_id UUID,
    event_status TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX audit_events_submission_id_idx
ON public.audit_events (submission_id);

CREATE INDEX audit_events_inquiry_id_idx
ON public.audit_events (inquiry_id);

CREATE INDEX audit_events_created_at_idx
ON public.audit_events (created_at);
