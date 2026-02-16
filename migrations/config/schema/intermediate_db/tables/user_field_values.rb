# frozen_string_literal: true

Migrations::Database::Schema.table :user_field_values do
  copy_structure_from :user_custom_fields
  primary_key :user_id, :field_id, :value

  add_column :field_id, :numeric
  add_column :is_multiselect_field, :boolean

  ignore :id, :name
end
