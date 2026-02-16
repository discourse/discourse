# frozen_string_literal: true

Migrations::Database::Schema.table :tag_group_permissions do
  primary_key :tag_group_id, :group_id, :permission_type

  column :permission_type, required: true

  ignore :id, "TODO: add reason"
end
