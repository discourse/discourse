# frozen_string_literal: true

class MigrateDfpToExcludeGroups < ActiveRecord::Migration[7.0]
  def up
    dfp_display_groups_raw =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'dfp_display_groups'").first

    if dfp_display_groups_raw.present?
      dfp_exclude_groups =
        case dfp_display_groups_raw
        when "10"
          "3|11|12|13|14"
        when "10|11"
          "3|12|13|14"
        when "10|11|12"
          "3|13|14"
        when "10|11|12|13"
          "3|14"
        when "10|11|12|14"
          "3"
        end

      DB.exec(<<~SQL, setting: dfp_exclude_groups)
        INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('dfp_exclude_groups', :setting, '20', NOW(), NOW())
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
