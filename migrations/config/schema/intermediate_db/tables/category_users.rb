# frozen_string_literal: true

Migrations::Database::Schema.table :category_users do
  primary_key :category_id, :user_id

  ignore :id
end
