# frozen_string_literal: true

Migrations::Database::Schema.table :topic_allowed_users do
  primary_key :topic_id, :user_id

  ignore :id
end
