# frozen_string_literal: true

class MigrateTlToGroupSettingsAdbutlerThroughTl < ActiveRecord::Migration[7.0]
  def up
    adbutler_through_trust_level_raw =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'adbutler_through_trust_level'",
      ).first

    if adbutler_through_trust_level_raw.present?
      adbutler_display_groups =
        case adbutler_through_trust_level_raw
        when "0"
          "10"
        when "1"
          "10|11"
        when "2"
          "10|11|12"
        when "3"
          "10|11|12|13"
        when "4"
          "10|11|12|13|14"
        end

      DB.exec(<<~SQL, setting: adbutler_display_groups)
        INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('adbutler_display_groups', :setting, '20', NOW(), NOW())
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
