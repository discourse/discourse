# frozen_string_literal: true

Migrations::Database::Schema.table :user_field_values do
  copy_structure_from :user_custom_fields
  primary_key :user_id, :field_id, :value

  add_column :field_id, :numeric
  add_column :is_multiselect_field, :boolean

  unique_index :user_id,
               :field_id,
               :value,
               where: "is_multiselect_field = TRUE",
               name: "idx_unique_user_field_values_multiselect"

  unique_index :user_id,
               :field_id,
               where: "is_multiselect_field = FALSE",
               name: "idx_unique_user_field_values_not_multiselect"

  ignore :id, :name
end
