

ALTER TABLE public.inquiries
ADD COLUMN needs_manual_review BOOLEAN NOT NULL DEFAULT FALSE;



UPDATE public.inquiries
SET needs_manual_review = TRUE
WHERE assigned_team IS NULL;



ALTER TABLE public.inquiries
ADD CONSTRAINT inquiries_assignment_review_check
CHECK (
    assigned_team IS NOT NULL
    OR needs_manual_review = TRUE
);
