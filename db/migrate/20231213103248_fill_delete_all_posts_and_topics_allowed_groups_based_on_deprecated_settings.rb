# frozen_string_literal: true

class FillDeleteAllPostsAndTopicsAllowedGroupsBasedOnDeprecatedSettings < ActiveRecord::Migration[
  7.0
]
  def up
    currently_enabled =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'tl4_delete_posts_and_topics' AND value = 't' LIMIT 1",
      ).first

    if currently_enabled == "t"
      # Matches Group::AUTO_GROUPS to the trust levels.
      tl4 = "14"

      # Data_type 20 is group_list.
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('delete_all_posts_and_topics_allowed_groups', :setting, '20', NOW(), NOW())",
        setting: tl4,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigrationError
  end
end
