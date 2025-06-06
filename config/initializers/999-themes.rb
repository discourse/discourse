# frozen_string_literal: true

Rails.application.config.after_initialize do |config|
  if Rails.env.development?
    require "listen"

    listener =
      Listen.to("#{Rails.root}/themes") do |modified, added, removed|
        filepath = modified.first || added.first || removed.first
        theme_name = filepath.gsub("#{Rails.root}/themes/", "").split("/").first

        Rails.logger.info "Theme folder changed. Syncing #{theme_name}..."
        if modified.length == 1 && added.length == 0 && removed.length == 0
          theme = Theme.find(Theme::CORE_THEMES[theme_name])
          relative_path = filepath.gsub("#{Rails.root}/themes/#{theme_name}/javascripts/", "")
          theme_field = theme.theme_fields.where(name: relative_path).first
          return SystemThemesManager.sync_theme!(theme_name) if !theme_field

          theme_field.update!(value: File.read(modified[0]))
        else
          SystemThemesManager.sync_theme!(theme_name)
        end
      end
    listener.start
  end
end
