# frozen_string_literal: true

Rails.application.config.after_initialize do |config|
  if Rails.env.development?
    require "listen"

    class Watcher
      def watch
        listener =
          Listen.to("#{Rails.root}/themes") do |modified, added, removed|
            filepath = modified.first || added.first || removed.first
            theme_name = filepath.gsub("#{Rails.root}/themes/", "").split("/").first
            theme = Theme.find(Theme::CORE_THEMES[theme_name])

            Rails.logger.info "Theme folder changed. Syncing #{theme_name}..."
            if modified.length == 1 && added.length == 0 && removed.length == 0 &&
                 (
                   (theme_field = find_js_field(theme, filepath)) ||
                     (theme_field = find_scss_field(theme, filepath))
                 )
              theme_field.update!(value: File.read(modified[0]))
              theme.update_javascript_cache!
              Stylesheet::Manager.clear_theme_cache!
              Theme.expire_site_cache!
            else
              SystemThemesManager.sync_theme!(theme_name)
            end
            MessageBus.publish "/file-change", ["development-mode-theme-changed"]
          end
        listener.start
      end

      private

      def find_js_field(theme, filepath)
        theme
          .theme_fields
          .where(
            name: filepath.gsub("#{Rails.root}/themes/#{theme.name.downcase}/javascripts/", ""),
            type_id: ThemeField.types[:js],
          )
          .first
      end

      def find_scss_field(theme, filepath)
        theme
          .theme_fields
          .where(name: filepath.split("/").last.split(".").first, type_id: ThemeField.types[:scss])
          .first
      end
    end

    Watcher.new.watch
  end
end
