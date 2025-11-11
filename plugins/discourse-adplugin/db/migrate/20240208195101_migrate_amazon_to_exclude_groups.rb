# frozen_string_literal: true

class MigrateAmazonToExcludeGroups < ActiveRecord::Migration[7.0]
  def up
    amazon_display_groups_raw =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'amazon_display_groups'").first

    if amazon_display_groups_raw.present?
      amazon_exclude_groups =
        case amazon_display_groups_raw
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

      DB.exec(<<~SQL, setting: amazon_exclude_groups)
        INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('amazon_exclude_groups', :setting, '20', NOW(), NOW())
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
