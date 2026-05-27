# frozen_string_literal: true

Migrations::Database::Schema.table :tag_users do
  primary_key :tag_id, :user_id

  ignore :id
end
