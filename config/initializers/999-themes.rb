# frozen_string_literal: true

CORE_THEMES = { "Horizon" => -1 }

Rails.application.config.to_prepare do |config|
  CORE_THEMES.each do |theme_name, theme_id|
    RemoteTheme.import_theme_from_directory(
      "#{Rails.root}/themes/#{theme_name}",
      theme_id: theme_id,
    )
  end
  if Rails.env == "development"
    Rails.application.config.watchable_dirs["themes"] = %w[rb scss css js gjs yml]
  end
end
