# frozen_string_literal: true

class MigrateDeprecatedHolidayRegionCodes < ActiveRecord::Migration[8.0]
  def up
    regions = {
      "el" => "gr",
      "us_az" => "us",
      "us_co" => "us",
      "us_gu" => "us",
      "us_id" => "us",
      "us_mt" => "us",
      "us_ny" => "us",
      "us_oh" => "us",
      "us_sd" => "us",
      "us_vi" => "us",
      "us_wy" => "us",
    }

    sql = []

    regions.each do |old_region, new_region|
      sql << "UPDATE user_custom_fields SET value = '#{new_region}' WHERE name = 'holidays-region' AND value = '#{old_region}'"
      sql << "UPDATE calendar_events SET region = '#{new_region}' WHERE region = '#{old_region}'"
      sql << "UPDATE discourse_calendar_disabled_holidays SET region_code = '#{new_region}' WHERE region_code = '#{old_region}'"
    end

    execute sql.join(";\n")
  end

  def down
    # NOTE: we can't revert US state codes back to their original values
    regions = { "gr" => "el" }

    sql = []

    regions.each do |new_region, old_region|
      sql << "UPDATE user_custom_fields SET value = '#{new_region}' WHERE name = 'holidays-region' AND value = '#{old_region}'"
      sql << "UPDATE calendar_events SET region = '#{new_region}' WHERE region = '#{old_region}'"
      sql << "UPDATE discourse_calendar_disabled_holidays SET region_code = '#{new_region}' WHERE region_code = '#{old_region}'"
    end

    execute sql.join(";\n")
  end
end
