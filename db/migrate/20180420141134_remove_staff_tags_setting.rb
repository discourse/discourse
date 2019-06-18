# frozen_string_literal: true

class RemoveStaffTagsSetting < ActiveRecord::Migration[5.1]
  def up
    execute "INSERT INTO tag_group_permissions
      (tag_group_id, group_id, permission_type, created_at, updated_at)
      SELECT id, #{Group::AUTO_GROUPS[:everyone]},
             #{TagGroupPermission.permission_types[:full]},
             now(), now()
        FROM tag_groups
       WHERE id NOT IN (SELECT tag_group_id FROM tag_group_permissions)"

    result = execute("SELECT value FROM site_settings WHERE name = 'staff_tags'").to_a
    if result.length > 0
      if tags = result[0]['value']&.split('|')
        tag_group = execute(
          "INSERT INTO tag_groups (name, created_at, updated_at)
           VALUES ('staff tags', now(), now())
           RETURNING id"
        )

        tag_group_id = tag_group[0]['id']

        execute(
          "INSERT INTO tag_group_permissions
          (tag_group_id, group_id, permission_type, created_at, updated_at)
          VALUES
          (#{tag_group_id}, #{Group::AUTO_GROUPS[:everyone]},
           #{TagGroupPermission.permission_types[:readonly]}, now(), now()),
          (#{tag_group_id}, #{Group::AUTO_GROUPS[:staff]},
           #{TagGroupPermission.permission_types[:full]}, now(), now())"
        )

        tags.each do |tag_name|
          tag = execute("SELECT id FROM tags WHERE name = '#{tag_name}'").to_a
          if tag[0] && tag[0]['id']
            execute(
              "INSERT INTO tag_group_memberships
              (tag_id, tag_group_id, created_at, updated_at)
              VALUES
              (#{tag[0]['id']}, #{tag_group_id}, now(), now())"
            )
          end
        end
      end
    end

    execute "DELETE FROM site_settings WHERE name = 'staff_tags'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
