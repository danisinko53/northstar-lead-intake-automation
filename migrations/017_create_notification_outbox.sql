CREATE TABLE public.notification_outbox (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    inquiry_id UUID NOT NULL
        REFERENCES public.inquiries(inquiry_id),

    notification_type TEXT NOT NULL DEFAULT 'team_assignment',

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'sent', 'failed')),

    attempt_count INTEGER NOT NULL DEFAULT 0
        CHECK (attempt_count >= 0),

    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    claimed_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,

    last_error_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT notification_outbox_unique_event
        UNIQUE (inquiry_id, notification_type)
);

CREATE INDEX notification_outbox_pending_idx
ON public.notification_outbox (
    next_attempt_at,
    created_at
)
WHERE status IN ('pending', 'failed');

CREATE INDEX notification_outbox_stale_claim_idx
ON public.notification_outbox (claimed_at)
WHERE status = 'processing';
