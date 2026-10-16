# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        # Themes are applied in two passes: first every theme's code (so all
        # themes exist), then the relations and settings that refer to others.
        class Themes
          def initialize(bundle, values, lookup, dry_run:)
            @bundle = bundle
            @values = values
            @lookup = lookup
            @dry_run = dry_run
          end

          def apply_code(entry)
            case entry["kind"]
            when "system"
              @lookup.theme(entry)
              :unchanged
            when "git"
              apply_git(entry)
            when "local"
              apply_local(entry)
            else
              raise Error, "unknown theme kind: #{entry["kind"].inspect}"
            end
          end

          def apply_relations(entry)
            theme = @lookup.theme(theme_ref(entry))
            changes = []
            problems = []

            changes << "attributes" if apply_attributes(theme, entry)
            changes << "children" if apply_children(theme, entry, problems)
            changes << "settings" if apply_settings(theme, entry, problems)
            changes << "theme site settings" if apply_theme_site_settings(theme, entry)
            changes << "translation overrides" if apply_translation_overrides(theme, entry)

            raise Error, problems.join("; ") if problems.any?
            changes.any? ? [:changed, changes.join(", ")] : :unchanged
          end

          private

          def theme_ref(entry)
            entry["kind"] == "system" ? entry.slice("system_id") : { "name" => entry["name"] }
          end

          def apply_git(entry)
            url = entry["remote_url"].to_s
            raise Error, "remote_url is missing" if url.blank?

            existing =
              ::Theme.joins(:remote_theme).where(remote_themes: { remote_url: url }).exists?
            return :unchanged if existing
            return :changed, "would be installed" if @dry_run

            ::RemoteTheme.import_theme(
              url,
              ::Discourse.system_user,
              branch: entry["branch"].presence,
            )
            [:changed, "installed"]
          end

          def apply_local(entry)
            dir = @bundle.directory_path(entry["dir"], prefix: Bundle::THEMES_DIR)
            existing = local_themes(entry["name"])
            if existing.size > 1
              raise Error, "#{existing.size} local themes are named '#{entry["name"]}'"
            end

            if (theme = existing.first)
              return :unchanged if ThemeFiles.same?(theme, dir)
              return :changed if @dry_run

              ::RemoteTheme.import_theme_from_directory(dir, theme_id: theme.id)
              :changed
            else
              return :changed, "would be created" if @dry_run

              ::RemoteTheme.import_theme_from_directory(dir)
              [:changed, "created"]
            end
          end

          def local_themes(name)
            ::Theme
              .where(name: name.to_s)
              .where("themes.id > 0")
              .left_joins(:remote_theme)
              .where("remote_themes.id IS NULL OR remote_themes.remote_url = ''")
              .to_a
          end

          def apply_attributes(theme, entry)
            desired = { "enabled" => entry["enabled"] != false }
            desired["user_selectable"] = entry["user_selectable"] == true if !theme.component
            desired["color_scheme_id"] = scheme_id(entry["color_scheme"])
            desired["dark_color_scheme_id"] = scheme_id(entry["dark_color_scheme"])

            changed = desired.reject { |key, value| theme.read_attribute(key) == value }
            return false if changed.empty?

            unless @dry_run
              theme.assign_attributes(changed)
              theme.save!
            end
            true
          end

          def scheme_id(ref)
            ref && @lookup.color_scheme!(ref).id
          end

          # Only adds children; components attached on the target stay.
          def apply_children(theme, entry, problems)
            current = theme.child_themes.pluck(:id)
            missing =
              Array(entry["children"]).filter_map do |ref|
                child = @lookup.theme(ref)
                child unless current.include?(child.id)
              rescue Error => e
                problems << e.message
                nil
              end
            return false if missing.empty?

            missing.each { |child| theme.add_relative_theme!(:child, child) } unless @dry_run
            true
          end

          def apply_settings(theme, entry, problems)
            definitions = theme.settings
            changed = false

            Array(entry["settings"]).each do |setting|
              name = setting["name"].to_s
              definition = definitions[name.to_sym]
              if definition.nil?
                problems << "setting #{name} is not defined by the theme"
                next
              end

              desired = setting_value(definition, setting["value"])
              next if same_setting?(theme, definition, desired)

              changed = true
              theme.update_setting(name.to_sym, desired) unless @dry_run
            end

            theme.save! if changed && !@dry_run
            changed
          end

          def setting_value(definition, value)
            case definition.type_name
            when :upload
              id = @values.upload(value)
              id && ::Upload.find(id).url
            when :objects
              @values.objects(value, definition.schema)
            else
              ::ThemeSettingsManager.cast_row_value(
                ::ThemeSetting.new(data_type: definition.type, value:),
              )
            end
          end

          def same_setting?(theme, definition, desired)
            row =
              theme.theme_settings.find_by(name: definition.name.to_s, data_type: definition.type)
            return false if row.nil?

            case definition.type_name
            when :upload
              upload_id = desired && ::Upload.find_by(url: desired)&.id
              row.value.to_s == upload_id.to_s
            when :objects
              row.json_value == desired
            else
              row.value.to_s == desired.to_s
            end
          end

          def apply_theme_site_settings(theme, entry)
            changed = false

            Array(entry["theme_site_settings"]).each do |setting|
              name = setting["name"].to_s
              current = theme.theme_site_settings.find_by(name:)
              next if current && current.value == setting["value"]

              changed = true
              next if @dry_run

              result =
                ::Themes::ThemeSiteSettingManager.call(
                  guardian: ::Discourse.system_user.guardian,
                  params: {
                    theme_id: theme.id,
                    name:,
                    value: setting["value"],
                  },
                )
              raise Error, "could not set theme site setting #{name}" unless result.success?
            end

            changed
          end

          def apply_translation_overrides(theme, entry)
            changed = false

            Array(entry["translation_overrides"]).each do |override|
              record =
                ::ThemeTranslationOverride.find_or_initialize_by(
                  theme_id: theme.id,
                  locale: override["locale"].to_s,
                  translation_key: override["key"].to_s,
                )
              next if record.value == override["value"]

              changed = true
              record.update!(value: override["value"]) unless @dry_run
            end

            changed
          end
        end
      end
    end
  end
end
