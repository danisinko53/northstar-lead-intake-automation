

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
BEGIN

    IF p_payload IS NULL
       OR jsonb_typeof(p_payload) <> 'object' THEN
        RAISE EXCEPTION 'Payload must be a JSON object.';
    END IF;

    v_submission_id :=
        (p_payload->>'submission_id')::UUID;

    IF v_submission_id IS NULL THEN
        RAISE EXCEPTION 'submission_id is required.';
    END IF;


    v_payload_hash := encode(
        sha256(
            convert_to(p_payload::TEXT, 'UTF8')
        ),
        'hex'
    );


    PERFORM pg_advisory_xact_lock(
        hashtextextended(v_submission_id::TEXT, 0)
    );


    SELECT
        inquiry_id,
        customer_id,
        payload_hash
    INTO
        v_existing_inquiry_id,
        v_existing_customer_id,
        v_existing_hash
    FROM public.inquiries
    WHERE submission_id = v_submission_id;

    IF FOUND THEN
        IF v_existing_hash = v_payload_hash THEN
            RETURN jsonb_build_object(
                'result', 'duplicate',
                'inquiry_id', v_existing_inquiry_id,
                'submission_id', v_submission_id,
                'customer_id', v_existing_customer_id,
                'duplicate', TRUE
            );
        END IF;

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

    IF v_customer_id IS NULL THEN
        SELECT customer_id
        INTO v_customer_id
        FROM public.customers
        WHERE normalized_email =
            p_payload->>'normalized_email';
    END IF;

    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION
            'Customer could not be resolved.';
    END IF;


    SELECT assigned_team
    INTO v_assigned_team
    FROM public.service_routing
    WHERE service_type = p_payload->>'service_type'
      AND is_active = TRUE;


    v_needs_manual_review :=
        v_assigned_team IS NULL;


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
        needs_manual_review
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
        v_needs_manual_review
    )
    RETURNING inquiry_id INTO v_inquiry_id;

    RETURN jsonb_build_object(
        'result', 'created',
        'inquiry_id', v_inquiry_id,
        'submission_id', v_submission_id,
        'customer_id', v_customer_id,
        'duplicate', FALSE
    );
END;
$$;
