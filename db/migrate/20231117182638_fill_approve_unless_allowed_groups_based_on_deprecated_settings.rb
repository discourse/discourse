# frozen_string_literal: true

class FillApproveUnlessAllowedGroupsBasedOnDeprecatedSettings < ActiveRecord::Migration[7.0]
  def up
    approve_unless_trust_level_raw =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'approve_unless_trust_level' LIMIT 1",
      ).first

    # Default for old setting is TL0, we only need to do anything if it's been changed in the DB.
    if approve_unless_trust_level_raw.present?
      # Matches Group::AUTO_GROUPS to the trust levels.
      approve_unless_allowed_groups = "1#{approve_unless_trust_level_raw}"

      # Data_type 20 is group_list
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('approve_unless_allowed_groups', :setting, '20', NOW(), NOW())",
        setting: approve_unless_allowed_groups,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
