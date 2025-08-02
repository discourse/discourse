# frozen_string_literal: true

class FillEmailInAllowedGroupsBasedOnDeprecatedSettings < ActiveRecord::Migration[7.0]
  def up
    email_in_min_trust_raw =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'email_in_min_trust' LIMIT 1",
      ).first

    # Default for old setting is TL0, we only need to do anything if it's been changed in the DB.
    if email_in_min_trust_raw.present?
      # Matches Group::AUTO_GROUPS to the trust levels.
      email_in_allowed_groups = "1#{email_in_min_trust_raw}"

      # Data_type 20 is group_list
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('email_in_allowed_groups', :setting, '20', NOW(), NOW())",
        setting: email_in_allowed_groups,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
