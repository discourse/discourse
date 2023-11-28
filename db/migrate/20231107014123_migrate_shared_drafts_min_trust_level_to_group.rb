# frozen_string_literal: true

class MigrateSharedDraftsMinTrustLevelToGroup < ActiveRecord::Migration[7.0]
  def up
    shared_drafts_min_trust_level_raw =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'shared_drafts_min_trust_level'",
      ).first

    # Default for old setting is staff and is TrustLevelAndStaffSetting, we only need to do anything if it's been changed in the DB.
    if shared_drafts_min_trust_level_raw.present?
      # Matches Group::AUTO_GROUPS to the trust levels & special admin/staff cases.
      shared_drafts_allowed_groups =
        case shared_drafts_min_trust_level_raw
        when "admin"
          "1"
        when "staff"
          "3"
        when "0"
          "10"
        when "1"
          "11"
        when "2"
          "12"
        when "3"
          "13"
        when "4"
          "14"
        end

      # Data_type 20 is group_list.
      DB.exec(<<~SQL, setting: shared_drafts_allowed_groups)
        INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('shared_drafts_allowed_groups', :setting, 20, NOW(), NOW())
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
