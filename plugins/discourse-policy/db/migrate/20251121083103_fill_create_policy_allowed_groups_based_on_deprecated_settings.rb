# frozen_string_literal: true

class FillCreatePolicyAllowedGroupsBasedOnDeprecatedSettings < ActiveRecord::Migration[8.0]
  def up
    restricted =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'policy_restrict_to_staff_posts' LIMIT 1",
      ).first

    # If deprecated setting is unrestricted, allow staff and TL0. Else default is fine.
    if restricted == "f"
      # Data_type 20 is group_list.
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('create_policy_allowed_groups', '1|2|10', '20', NOW(), NOW())",
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
