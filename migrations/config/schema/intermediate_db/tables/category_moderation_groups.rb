# frozen_string_literal: true

Migrations::Database::Schema.table :category_moderation_groups do
  primary_key :category_id, :group_id

  ignore :created_at, :id
end
