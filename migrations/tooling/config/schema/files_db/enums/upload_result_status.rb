# frozen_string_literal: true

Migrations::Tooling::Schema.enum :upload_result_status do
  value :ok, "ok"
  value :skipped, "skipped"
  value :error, "error"
end
