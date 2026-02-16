# frozen_string_literal: true

Migrations::Database::Schema.table :topic_users do
  primary_key :topic_id, :user_id

  ignore :id, "TODO: add reason"
  ignore :bookmarked, "TODO: add reason"
  ignore :liked, "TODO: add reason"
  ignore :posted, "TODO: add reason"
end
