# frozen_string_literal: true

module Migrations::Importer::Steps
  class SiteSettingBasics < Base::SiteSettings
    title "Importing basic site settings"
    priority 0

    protected

    def skip_row?(row)
      name = row[:name].to_sym
      setting = @settings_index[name]

      # Can't skip unknown settings here; we need to count them in the progress bar.
      return false if setting.nil?

      DATATYPES_WITH_DEPENDENCY.include?(setting[:type])
    end
  end
end
