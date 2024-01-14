# frozen_string_literal: true

class FillSelfWikiAllowedGroupsBasedOnDeprecatedSettings < ActiveRecord::Migration[7.0]
  def up
    configured_trust_level =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'min_trust_to_allow_self_wiki' LIMIT 1",
      ).first

    # Default for old setting is TL3, we only need to do anything if it's been changed in the DB.
    if configured_trust_level.present?
      corresponding_group = "1#{configured_trust_level}"

      # Data_type 20 is group_list.
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('self_wiki_allowed_groups', :setting, '20', NOW(), NOW())",
        setting: corresponding_group,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
