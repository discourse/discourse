# frozen_string_literal: true

class FillCreateTagAllowedGroupsBasedOnDeprecatedSettings < ActiveRecord::Migration[7.0]
  def up
    configured_trust_level =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'min_trust_to_create_tag' LIMIT 1",
      ).first

    # Default for old setting is TL3, we only need to do anything if it's been changed in the DB.
    if configured_trust_level.present?
      corresponding_group =
        case configured_trust_level
        when "admin"
          "1"
        when "staff"
          "1|3"
          # Matches Group::AUTO_GROUPS to the trust levels.
        else
          "1|3|1#{configured_trust_level}"
        end

      # Data_type 20 is group_list.
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('create_tag_allowed_groups', :setting, '20', NOW(), NOW())",
        setting: corresponding_group,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
