ALTER TABLE inquiries
ADD CONSTRAINT inquiries_message_length
CHECK (LENGTH(TRIM(message)) >= 10 AND LENGTH(TRIM(message)) <= 2000);
