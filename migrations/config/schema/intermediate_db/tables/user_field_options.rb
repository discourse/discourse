# frozen_string_literal: true

Migrations::Database::Schema.table :user_field_options do
  primary_key :user_field_id, :value

  ignore :id
end
