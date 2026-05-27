# frozen_string_literal: true

Migrations::Database::Schema.enum :upload_type do
  source { ::UploadCreator::TYPES_TO_CROP }
end
