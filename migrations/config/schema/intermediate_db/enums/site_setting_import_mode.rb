# frozen_string_literal: true

Migrations::Database::Schema.enum :site_setting_import_mode do
  value :auto, 0
  value :override, 1
  value :append, 2
end
