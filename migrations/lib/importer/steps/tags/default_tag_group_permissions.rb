# frozen_string_literal: true

module Migrations::Importer::Steps
  class DefaultTagGroupPermissions < ::Migrations::Importer::Step
    depends_on :tag_group_permissions

    def execute
      super

      everyone_group_id = Group::AUTO_GROUPS[:everyone]
      full_permission_type = TagGroupPermission.permission_types[:full]

      DB.exec(<<~SQL, everyone_group_id, full_permission_type)
        INSERT INTO tag_group_permissions (tag_group_id, group_id, permission_type, created_at, updated_at)
        SELECT tag_groups.id, ?, ?, tag_groups.created_at, tag_groups.updated_at
        FROM tag_groups
             LEFT JOIN tag_group_permissions ON tag_groups.id = tag_group_permissions.tag_group_id
        WHERE tag_group_permissions.tag_group_id IS NULL
        ON CONFLICT DO NOTHING
      SQL
    end
  end
end
