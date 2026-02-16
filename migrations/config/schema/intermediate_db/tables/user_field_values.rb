# frozen_string_literal: true

Migrations::Database::Schema.table :user_field_values do
  copy_structure_from :user_custom_fields

  add_column :field_id, :numeric, required: true
  add_column :is_multiselect_field, :boolean

  ignore :id
  ignore :name

  unique_index %i[user_id field_id value],
               name: :user_field_values_multiselect_index,
               where: "WHERE is_multiselect_field = TRUE"
  unique_index %i[user_id field_id],
               name: :user_field_values_not_multiselect_index,
               where: "WHERE is_multiselect_field = FALSE"
end
