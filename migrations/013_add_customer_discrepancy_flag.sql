ALTER TABLE public.inquiries
ADD COLUMN has_customer_discrepancy BOOLEAN
NOT NULL DEFAULT FALSE;
