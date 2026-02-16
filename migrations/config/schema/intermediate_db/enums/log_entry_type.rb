# frozen_string_literal: true

Migrations::Database::Schema.enum :log_entry_type do
  string_value :info, "info"
  string_value :warning, "warning"
  string_value :error, "error"
end
