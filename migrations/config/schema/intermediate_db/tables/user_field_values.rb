# frozen_string_literal: true

Migrations::Database::Schema.table :user_field_values do
  copy_structure_from :user_custom_fields
  primary_key :user_id, :field_id, :value

  add_column :field_id, :numeric
  add_column :is_multiselect_field, :boolean

  unique_index :user_id,
               :field_id,
               :value,
               name: :user_field_values_multiselect_index,
               where: "is_multiselect_field = TRUE"
  unique_index :user_id,
               :field_id,
               name: :user_field_values_not_multiselect_index,
               where: "is_multiselect_field = FALSE"

  ignore :id, :name
end
