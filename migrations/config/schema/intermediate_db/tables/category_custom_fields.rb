# frozen_string_literal: true

Migrations::Database::Schema.table :category_custom_fields do
  primary_key :category_id, :name

  ignore :created_at, :id
end
