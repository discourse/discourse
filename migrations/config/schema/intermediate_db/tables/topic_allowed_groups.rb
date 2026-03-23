# frozen_string_literal: true

Migrations::Database::Schema.table :topic_allowed_groups do
  primary_key :topic_id, :group_id

  ignore :id
end
