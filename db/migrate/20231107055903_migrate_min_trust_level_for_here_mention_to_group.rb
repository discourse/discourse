# frozen_string_literal: true

class MigrateMinTrustLevelForHereMentionToGroup < ActiveRecord::Migration[7.0]
  def up
    min_trust_level_for_here_mention_raw =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'min_trust_level_for_here_mention'",
      ).first

    # Default for old setting is trust level 2 and is TrustLevelAndStaffSetting, we only need to do anything if it's been changed in the DB.
    if min_trust_level_for_here_mention_raw.present?
      # Matches Group::AUTO_GROUPS to the trust levels & special admin/staff cases.
      here_mention_allowed_groups =
        case min_trust_level_for_here_mention_raw
        when "admin"
          "1"
        when "staff"
          "1|3"
          # Matches Group::AUTO_GROUPS to the trust levels.
        else
          "1|3|1#{min_trust_level_for_here_mention_raw}"
        end

      # Data_type 20 is group_list.
      DB.exec(<<~SQL, setting: here_mention_allowed_groups)
        INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('here_mention_allowed_groups', :setting, 20, NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
