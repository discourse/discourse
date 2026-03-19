# frozen_string_literal: true

Migrations::Database::Schema.table :topic_users do
  primary_key :topic_id, :user_id

  ignore :id
  ignore :bookmarked, :liked, :posted, reason: "Calculated columns"
end
