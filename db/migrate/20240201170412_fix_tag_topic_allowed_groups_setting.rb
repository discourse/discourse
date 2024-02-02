# frozen_string_literal: true

class FixTagTopicAllowedGroupsSetting < ActiveRecord::Migration[7.0]
  def up
    configured_trust_level =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'min_trust_level_to_tag_topics' LIMIT 1",
      ).first

    configured_groups =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'tag_topic_allowed_groups' LIMIT 1",
      ).first

    # We only need to do anything if it's been changed in the DB.
    if configured_trust_level.present? && configured_groups.present?
      # The previous migration for this, changed it to only
      # `"1#{configured_trust_level}"`, so if it has been
      # changed we need to add back in admin & staff if they match.
      if "1#{configured_trust_level}" == configured_groups
        corresponding_group = "1|3|1#{configured_trust_level}"
      end

      # Just in case this happend in the previous migration.
      corresponding_group =
        case configured_groups
        when "1admin"
          "1"
        when "1staff"
          "1|3"
        end

      if corresponding_group
        DB.exec(
          "UPDATE site_settings SET value = :setting, updated_at = NOW() WHERE name = 'tag_topic_allowed_groups'",
          setting: corresponding_group,
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
