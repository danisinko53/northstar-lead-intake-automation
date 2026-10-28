
CREATE TABLE inquiries (
    inquiry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES customers(customer_id),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NULL,
    service_type TEXT NOT NULL CHECK (
    service_type IN (
        'plumbing',
        'electrical',
        'hvac',
        'general_repair'
    )
),
    zip_code TEXT NOT NULL,
    message TEXT NOT NULL,
    assigned_team TEXT NULL,
    status TEXT NOT NULL DEFAULT 'new' CHECK (
    status IN (
        'new',
        'assigned',
        'contacted',
        'qualified',
        'closed',
        'cancelled'
    )
),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    submitted_at TIMESTAMPTZ NOT NULL,
    payload_hash TEXT NOT NULL
);
