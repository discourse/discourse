# frozen_string_literal: true

Fabricator(:tag_group_permission) do
  tag_group
  group
  permission_type TagGroupPermission.permission_types[:readonly]
end
