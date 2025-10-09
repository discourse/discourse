# frozen_string_literal: true

module Migrations::Importer::Steps
  class SiteSettingBasics < Base::SiteSettings
    title "Importing basic site settings"
    priority 0

    protected

    def skipped_row?(row)
      name = row[:name].to_sym
      setting = @all_settings_by_name[name]

      # we can't skip unknown settings here, we need to handle them within the progressbar
      return false if setting.nil?

      DATATYPES_WITH_DEPENDENCY.include?(setting[:type])
    end
  end
end
