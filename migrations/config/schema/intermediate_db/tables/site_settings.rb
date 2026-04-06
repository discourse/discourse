# frozen_string_literal: true

Migrations::Database::Schema.table :site_settings do
  primary_key :name

  include :name, :value

  add_column :import_mode, :integer, enum: :site_setting_import_mode, required: true
  add_column :last_changed_at, :datetime

  ignore :created_at, :id, :data_type
end
