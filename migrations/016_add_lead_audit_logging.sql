
-- Migration 016
-- Transactional lead processing audit events
-- Northstar Home Services

CREATE OR REPLACE FUNCTION public.northstar_save_lead(
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_submission_id UUID;
    v_customer_id UUID;
    v_inquiry_id UUID;

    v_payload_hash TEXT;
    v_existing_hash TEXT;
    v_existing_inquiry_id UUID;
    v_existing_customer_id UUID;

    v_assigned_team TEXT;
    v_needs_manual_review BOOLEAN;
    v_has_customer_discrepancy BOOLEAN := FALSE;
    v_customer_created BOOLEAN := FALSE;

    v_customer_first_name TEXT;
    v_customer_last_name TEXT;
    v_customer_phone TEXT;

    v_status TEXT;
    v_created_at TIMESTAMPTZ;
BEGIN
    IF p_payload IS NULL
       OR jsonb_typeof(p_payload) <> 'object' THEN
        RAISE EXCEPTION 'Payload must be a JSON object.';
    END IF;

    v_submission_id := (p_payload->>'submission_id')::UUID;

    IF v_submission_id IS NULL THEN
        RAISE EXCEPTION 'submission_id is required.';
    END IF;

    v_payload_hash := encode(
        sha256(convert_to(p_payload::TEXT, 'UTF8')),
        'hex'
    );

    PERFORM pg_advisory_xact_lock(
        hashtextextended(v_submission_id::TEXT, 0)
    );

    INSERT INTO public.audit_events (
        event_type, submission_id, event_status
    )
    VALUES (
        'REQUEST_ACCEPTED', v_submission_id, 'accepted'
    );

    SELECT
        inquiry_id,
        customer_id,
        payload_hash,
        status,
        assigned_team,
        created_at
    INTO
        v_existing_inquiry_id,
        v_existing_customer_id,
        v_existing_hash,
        v_status,
        v_assigned_team,
        v_created_at
    FROM public.inquiries
    WHERE submission_id = v_submission_id;

    IF FOUND THEN
        IF v_existing_hash = v_payload_hash THEN

            INSERT INTO public.audit_events (
                event_type,
                submission_id,
                inquiry_id,
                event_status
            )
            VALUES (
                'DUPLICATE_DETECTED',
                v_submission_id,
                v_existing_inquiry_id,
                'duplicate'
            );

            RETURN jsonb_build_object(
                'result', 'duplicate',
                'inquiry_id', v_existing_inquiry_id,
                'submission_id', v_submission_id,
                'customer_id', v_existing_customer_id,
                'status', v_status,
                'assigned_team', v_assigned_team,
                'created_at', v_created_at,
                'duplicate', TRUE
            );
        END IF;

        -- Record the conflict without exposing payload content.
        INSERT INTO public.audit_events (
            event_type,
            submission_id,
            inquiry_id,
            event_status
        )
        VALUES (
            'SUBMISSION_CONFLICT',
            v_submission_id,
            v_existing_inquiry_id,
            'conflict'
        );

        RETURN jsonb_build_object(
            'result', 'conflict',
            'submission_id', v_submission_id,
            'duplicate', FALSE
        );
    END IF;

    INSERT INTO public.customers (
        first_name,
        last_name,
        email,
        normalized_email,
        phone
    )
    VALUES (
        p_payload->>'first_name',
        p_payload->>'last_name',
        p_payload->>'email',
        p_payload->>'normalized_email',
        p_payload->>'phone'
    )
    ON CONFLICT (normalized_email) DO NOTHING
    RETURNING customer_id INTO v_customer_id;

    v_customer_created := v_customer_id IS NOT NULL;

    IF NOT v_customer_created THEN
        SELECT
            customer_id,
            first_name,
            last_name,
            phone
        INTO
            v_customer_id,
            v_customer_first_name,
            v_customer_last_name,
            v_customer_phone
        FROM public.customers
        WHERE normalized_email = p_payload->>'normalized_email';

        IF v_customer_id IS NULL THEN
            RAISE EXCEPTION 'Customer could not be resolved.';
        END IF;

        v_has_customer_discrepancy :=
            v_customer_first_name IS DISTINCT FROM
                p_payload->>'first_name'
            OR v_customer_last_name IS DISTINCT FROM
                p_payload->>'last_name'
            OR v_customer_phone IS DISTINCT FROM
                p_payload->>'phone';
    END IF;

    INSERT INTO public.audit_events (
        event_type,
        submission_id,
        event_status,
        metadata
    )
    VALUES (
        CASE WHEN v_customer_created
            THEN 'CUSTOMER_CREATED'
            ELSE 'CUSTOMER_MATCHED'
        END,
        v_submission_id,
        'success',
        jsonb_build_object(
            'has_customer_discrepancy',
            v_has_customer_discrepancy
        )
    );

    SELECT assigned_team
    INTO v_assigned_team
    FROM public.service_routing
    WHERE service_type = p_payload->>'service_type'
      AND is_active = TRUE;

    v_needs_manual_review := v_assigned_team IS NULL;

    INSERT INTO public.inquiries (
        submission_id,
        customer_id,
        first_name,
        last_name,
        email,
        phone,
        service_type,
        zip_code,
        message,
        submitted_at,
        payload_hash,
        assigned_team,
        needs_manual_review,
        has_customer_discrepancy
    )
    VALUES (
        v_submission_id,
        v_customer_id,
        p_payload->>'first_name',
        p_payload->>'last_name',
        p_payload->>'email',
        p_payload->>'phone',
        p_payload->>'service_type',
        p_payload->>'zip_code',
        p_payload->>'message',
        (p_payload->>'submitted_at')::TIMESTAMPTZ,
        v_payload_hash,
        v_assigned_team,
        v_needs_manual_review,
        v_has_customer_discrepancy
    )
    RETURNING
        inquiry_id, status, assigned_team, created_at
    INTO
        v_inquiry_id, v_status, v_assigned_team, v_created_at;

    INSERT INTO public.audit_events (
        event_type,
        submission_id,
        inquiry_id,
        event_status
    )
    VALUES (
        'INQUIRY_CREATED',
        v_submission_id,
        v_inquiry_id,
        'success'
    );

    INSERT INTO public.audit_events (
        event_type,
        submission_id,
        inquiry_id,
        event_status,
        metadata
    )
    VALUES (
        CASE WHEN v_needs_manual_review
            THEN 'ASSIGNMENT_FAILED'
            ELSE 'ASSIGNMENT_COMPLETED'
        END,
        v_submission_id,
        v_inquiry_id,
        CASE WHEN v_needs_manual_review
            THEN 'manual_review'
            ELSE 'success'
        END,
        jsonb_build_object(
            'service_type', p_payload->>'service_type',
            'assigned_team', v_assigned_team
        )
    );

    RETURN jsonb_build_object(
        'result', 'created',
        'inquiry_id', v_inquiry_id,
        'submission_id', v_submission_id,
        'customer_id', v_customer_id,
        'status', v_status,
        'assigned_team', v_assigned_team,
        'created_at', v_created_at,
        'duplicate', FALSE
    );
END;
$$;
