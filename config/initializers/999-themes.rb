# frozen_string_literal: true

Rails.application.config.after_initialize do |config|
  if Rails.env.development?
    require "listen"

    listener =
      Listen.to("#{Rails.root}/themes") do |modified, added, removed|
        filepath = modified.first || added.first || removed.first
        theme_name = filepath.gsub("#{Rails.root}/themes/", "").split("/").first

        Rails.logger.info "Theme folder changed. Syncing #{theme_name}..."
        SystemThemesManager.sync_theme!(theme_name)
      end
    listener.start
  end
end
