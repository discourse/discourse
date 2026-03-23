# frozen_string_literal: true

Migrations::Database::Schema.table :topic_tags do
  primary_key :topic_id, :tag_id

  ignore :id
end
