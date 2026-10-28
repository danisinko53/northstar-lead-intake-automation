ALTER TABLE customers
ADD CONSTRAINT customers_email_length
CHECK (
    LENGTH(TRIM(email)) BETWEEN 1 AND 254
);
ALTER TABLE inquiries
ADD CONSTRAINT inquiries_email_length
CHECK (
    LENGTH(TRIM(email)) BETWEEN 1 AND 254
);
