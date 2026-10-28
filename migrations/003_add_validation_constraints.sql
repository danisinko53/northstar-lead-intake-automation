ALTER TABLE inquiries
ADD CONSTRAINT inquiries_zip_code_format
CHECK (zip_code ~ '^[0-9]{5}$');
