# frozen_string_literal: true

CORE_THEMES = { "Horizon" => -1 }
class CoreThemesManager
  def self.sync!
    CORE_THEMES.each do |theme_name, theme_id|
      RemoteTheme.import_theme_from_directory(
        "#{Rails.root}/themes/#{theme_name}",
        theme_id: theme_id,
      )
    end
  end
end
