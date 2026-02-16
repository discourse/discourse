# frozen_string_literal: true

Migrations::Database::Schema.table :category_moderation_groups do
  primary_key :category_id, :group_id

  column :category_id, required: true
  column :group_id, required: true

  ignore :created_at, "TODO: add reason"
  ignore :updated_at, "TODO: add reason"
  ignore :id, "TODO: add reason"
end
