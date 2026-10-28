
ALTER TABLE customers
ADD CONSTRAINT customers_first_name_length
CHECK (
    LENGTH(TRIM(first_name)) BETWEEN 1 AND 100
),
ADD CONSTRAINT customers_last_name_length
CHECK (
    LENGTH(TRIM(last_name)) BETWEEN 1 AND 100
);
