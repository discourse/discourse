# frozen_string_literal: true

Migrations::Tooling::Schema.table :topic_users do
  primary_key :topic_id, :user_id

  ignore :id
  ignore :bookmarked, :liked, :posted, reason: "Calculated columns"
end
