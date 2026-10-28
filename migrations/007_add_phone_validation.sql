ALTER TABLE customers
ADD CONSTRAINT customers_phone_length
CHECK (
    phone IS NULL
    OR LENGTH(TRIM(phone)) BETWEEN 7 AND 20
);
ALTER TABLE inquiries
ADD CONSTRAINT inquiries_phone_length
CHECK (
    phone IS NULL
    OR LENGTH(TRIM(phone)) BETWEEN 7 AND 20
);
