# frozen_string_literal: true

Migrations::Database::Schema.enum :log_entry_type do
  value :info, "info"
  value :warning, "warning"
  value :error, "error"
end
