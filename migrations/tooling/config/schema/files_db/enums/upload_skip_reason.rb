# frozen_string_literal: true

Migrations::Tooling::Schema.enum :upload_skip_reason do
  value :file_not_found, "file_not_found"
  value :too_many_retries, "too_many_retries"
  value :download_error, "download_error"
  value :upload_size_exceeded, "upload_size_exceeded"
  value :error, "error"
end
