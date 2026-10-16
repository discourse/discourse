# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        # Exports a whole theme: files for local themes, the repository for git
        # themes, and for every theme the settings and relations that live in
        # the database.
        class Themes
          def initialize(writer, values, output:)
            @writer = writer
            @values = values
            @output = output
          end

          def call(item)
            theme = find_theme(item)

            entry = { "name" => theme.name }
            entry.merge!(item.slice("target", "note"))
            entry.merge!(source(theme))
            entry.merge!(
              "component" => theme.component,
              "enabled" => theme.enabled,
              "user_selectable" => theme.user_selectable,
              "color_scheme" => @values.color_scheme_ref(theme.color_scheme),
              "dark_color_scheme" => @values.color_scheme_ref(theme.dark_color_scheme),
              "children" => theme.child_themes.map { |child| @values.theme_ref(child) },
              "settings" => settings(theme),
              "theme_site_settings" =>
                theme
                  .theme_site_settings
                  .order(:name)
                  .map { |s| { "name" => s.name, "value" => s.value } },
              "translation_overrides" =>
                theme
                  .theme_translation_overrides
                  .order(:locale, :translation_key)
                  .map do |o|
                    { "locale" => o.locale, "key" => o.translation_key, "value" => o.value }
                  end,
            )
          end

          private

          def find_theme(item)
            if item["system_id"]
              theme = ::Theme.find_by(id: item["system_id"].to_i)
              raise Error, "system theme #{item["system_id"]} does not exist" if theme.nil?
              return theme
            end

            themes = ::Theme.where(name: item["name"]).to_a
            raise Error, "theme does not exist" if themes.empty?
            if themes.size > 1
              raise Error, "#{themes.size} themes have this name; rename them to tell them apart"
            end
            themes.first
          end

          def source(theme)
            return { "kind" => "system", "system_id" => theme.id } if theme.id < 0

            remote = theme.remote_theme
            if remote&.remote_url.present?
              if remote.private_key.present?
                raise SkipItem, "private git repository; install it by hand"
              end
              @output.puts "Note: git theme '#{theme.name}' is exported as its repository URL only."
              return(
                { "kind" => "git", "remote_url" => remote.remote_url, "branch" => remote.branch }
              )
            end

            dir = ThemeFiles.export(theme) { |path| @writer.add_theme_directory(path, theme.name) }
            { "kind" => "local", "dir" => dir }
          end

          def settings(theme)
            definitions = theme.settings
            types = ::ThemeSetting.types.invert

            theme
              .theme_settings
              .order(:name)
              .map do |setting|
                type = types[setting.data_type].to_s
                value =
                  case type
                  when "upload"
                    @values.upload(setting.value)
                  when "objects"
                    @values.objects(setting.json_value, definitions[setting.name.to_sym]&.schema)
                  else
                    setting.value
                  end
                { "name" => setting.name, "type" => type, "value" => value }
              end
          end
        end
      end
    end
  end
end
