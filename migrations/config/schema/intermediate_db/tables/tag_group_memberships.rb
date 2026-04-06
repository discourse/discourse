# frozen_string_literal: true

Migrations::Database::Schema.table :tag_group_memberships do
  primary_key :tag_group_id, :tag_id

  ignore :id
end
