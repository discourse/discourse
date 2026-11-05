# frozen_string_literal: true

require "base64"
require "tempfile"

module DiscourseMcp
  module Tools
    module ThemeManagementSupport
      MAX_FILE_BYTES = 20 * 1024 * 1024
      MAX_ENCODED_BYTES = ((MAX_FILE_BYTES + 2) / 3) * 4

      module_function

      def find!(guardian, id)
        guardian.ensure_is_admin!
        theme =
          ::Theme.include_relations.find_by(id:) ||
            raise(ToolError, I18n.t("mcp.errors.theme_not_found"))
        guardian.ensure_can_edit_theme!(theme)
        theme
      end

      def confirm!(value)
        raise ToolError, I18n.t("mcp.errors.theme_confirmation_required") unless value == true
      end

      def check_name!(theme, name)
        raise ToolError, I18n.t("mcp.errors.theme_name_mismatch") unless theme.name == name
      end

      def summary(theme)
        {
          id: theme.id,
          name: theme.name,
          component: theme.component,
          enabled: theme.enabled,
          default: theme.default?,
          remote_theme_id: theme.remote_theme_id,
        }
      end

      def with_file(encoded, maximum: MAX_FILE_BYTES)
        if encoded.bytesize > ((maximum + 2) / 3) * 4
          raise ToolError, I18n.t("mcp.errors.upload_too_large")
        end
        begin
          data = Base64.strict_decode64(encoded)
        rescue ArgumentError
          raise ToolError, I18n.t("mcp.errors.invalid_upload_data")
        end
        raise ToolError, I18n.t("mcp.errors.upload_too_large") if data.bytesize > maximum
        Tempfile.create("mcp-theme", binmode: true) do |file|
          file.write(data)
          file.rewind
          yield file
        end
      end
    end

    class ListThemes
      REQUIRED_SCOPES = [Scopes::THEMES_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          themes: OutputSchema::OBJECT_ARRAY,
          has_more: OutputSchema::BOOLEAN,
          next_offset: OutputSchema::INTEGER_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_admin!
        limit = arguments.fetch("limit", 30)
        offset = arguments.fetch("offset", 0)
        themes = ::Theme.order(:name, :id).limit(limit + 1).offset(offset).to_a
        has_more = themes.size > limit
        ToolHelpers.text_and_structured(
          themes: themes.first(limit).map { |theme| ThemeManagementSupport.summary(theme) },
          has_more:,
          next_offset: has_more ? offset + limit : nil,
        )
      end
    end

    class DeleteTheme
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(theme_id: OutputSchema::INTEGER, deleted: OutputSchema::BOOLEAN)

      def self.call(arguments:, request_context:)
        theme = ThemeManagementSupport.find!(request_context.guardian, arguments.fetch("theme_id"))
        ThemeManagementSupport.confirm!(arguments["confirm"])
        ThemeManagementSupport.check_name!(theme, arguments.fetch("expected_name"))
        result = Themes::Destroy.call(guardian: request_context.guardian, params: { id: theme.id })
        raise Discourse::InvalidAccess if result["result.policy.can_edit_theme"]&.failure?
        if result.failure? || ::Theme.exists?(theme.id)
          raise ToolError, I18n.t("mcp.errors.theme_delete_failed")
        end
        ToolHelpers.text_and_structured(theme_id: theme.id, deleted: true)
      end
    end

    class InstallTheme
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          theme: OutputSchema::OBJECT,
          skipped_components: OutputSchema::OBJECT_ARRAY,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        guardian.ensure_can_create_theme!
        ThemeManagementSupport.confirm!(arguments["confirm_external_code"])
        if %w[remote_url archive_data].count { |key| arguments.key?(key) } != 1 ||
             [arguments["remote_url"], arguments["archive_data"]].none?(&:present?)
          raise ToolError, I18n.t("mcp.errors.theme_install_source_required")
        end
        if arguments["remote_url"].present?
          if (
               arguments.keys &
                 %w[filename replace_theme_id expected_name confirm_replace components]
             ).present?
            raise ToolError, I18n.t("mcp.errors.theme_install_options_invalid")
          end
          if arguments["run_migrations"] == false
            raise ToolError, I18n.t("mcp.errors.theme_repository_migrations_required")
          end
          ThemeManagementSupport.confirm!(arguments["confirm_run_migrations"])
          remote = arguments.fetch("remote_url").strip
          guardian.ensure_allowed_theme_repo_import!(remote)
          theme =
            RemoteTheme.import_theme(remote, guardian.user, branch: arguments["branch"], guardian:)
        else
          raise Discourse::InvalidAccess if !::Theme.allowed_remote_theme_ids.nil?
          if arguments.key?("branch") ||
               (
                 !arguments.key?("replace_theme_id") &&
                   (arguments.keys & %w[expected_name confirm_replace]).present?
               )
            raise ToolError, I18n.t("mcp.errors.theme_install_options_invalid")
          end
          filename = arguments.fetch("filename", "")
          unless filename.match?(/\.(zip|gz|tgz)\z/i)
            raise ToolError, I18n.t("themes.import_error.unknown_file_type")
          end
          if arguments["replace_theme_id"]
            existing = ThemeManagementSupport.find!(guardian, arguments["replace_theme_id"])
            raise Discourse::InvalidAccess if existing.system?
            ThemeManagementSupport.confirm!(arguments["confirm_replace"])
            ThemeManagementSupport.check_name!(existing, arguments["expected_name"])
          end
          run_migrations = arguments.fetch("run_migrations", false)
          components = arguments.fetch("components", "none")
          if components != "none" && !run_migrations
            raise ToolError, I18n.t("mcp.errors.theme_component_migrations_required")
          end
          ThemeManagementSupport.confirm!(arguments["confirm_run_migrations"]) if run_migrations
          theme =
            ThemeManagementSupport.with_file(arguments.fetch("archive_data")) do |file|
              RemoteTheme.update_zipped_theme(
                file.path,
                filename,
                user: guardian.user,
                theme_id: arguments["replace_theme_id"],
                update_components: components,
                run_migrations:,
                skip_component_failures: true,
                guardian:,
              )
            end
        end
        StaffActionLogger.new(guardian.user).log_theme_change(nil, theme)
        ToolHelpers.text_and_structured(
          theme: ThemeManagementSupport.summary(theme),
          skipped_components: theme.skipped_child_components || [],
        )
      rescue RemoteTheme::ImportError, ::Theme::SettingsMigrationError => error
        raise ToolError, error.message
      end
    end

    class SyncRemoteTheme
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          theme: OutputSchema::OBJECT,
          local_version: OutputSchema::STRING_OR_NULL,
          remote_version: OutputSchema::STRING_OR_NULL,
          skipped_components: OutputSchema::OBJECT_ARRAY,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        theme = ThemeManagementSupport.find!(guardian, arguments.fetch("theme_id"))
        remote = theme.remote_theme
        raise ToolError, I18n.t("mcp.errors.theme_not_remote") unless remote&.is_git?
        guardian.ensure_allowed_theme_repo_import!(remote.remote_url)
        if arguments.key?("expected_remote_url") &&
             arguments["expected_remote_url"] != remote.remote_url
          raise ToolError, I18n.t("mcp.errors.theme_remote_mismatch")
        end
        if arguments.fetch("action") == "update"
          ThemeManagementSupport.confirm!(arguments["confirm_external_code"])
          ThemeManagementSupport.confirm!(arguments["confirm_run_migrations"])
          original = ThemeSerializer.new(theme, root: false).to_json
          remote.update_from_remote(raise_on_import_error: true, guardian:)
          StaffActionLogger.new(guardian.user).log_theme_change(original, theme.reload)
        else
          remote.update_remote_version
        end
        raise ToolError, remote.last_error_text if remote.last_error_text.present?
        ToolHelpers.text_and_structured(
          theme: ThemeManagementSupport.summary(theme.reload),
          local_version: remote.local_version,
          remote_version: remote.remote_version,
          skipped_components: remote.skipped_child_components,
        )
      rescue RemoteTheme::ImportError, ::Theme::SettingsMigrationError => error
        raise ToolError, error.message
      end
    end

    class UploadThemeAsset
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(upload_id: OutputSchema::INTEGER, attached: OutputSchema::BOOLEAN)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        guardian.ensure_is_admin!
        raise Discourse::InvalidAccess if !::Theme.allowed_remote_theme_ids.nil?
        filename = arguments.fetch("filename")
        maximum = [
          [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes,
          ThemeManagementSupport::MAX_FILE_BYTES,
        ].min
        upload =
          ThemeManagementSupport.with_file(arguments.fetch("file_data"), maximum:) do |file|
            UploadCreator.new(file, filename, for_theme: true).create_for(guardian.user.id)
          end
        raise ToolError, upload.errors.full_messages.join(", ") if upload.errors.present?
        ToolHelpers.text_and_structured(upload_id: upload.id, attached: false)
      end
    end

    class UpdateThemeSetting
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      OUTPUT_SCHEMA = OutputSchema.object(name: OutputSchema::STRING, value: OutputSchema::ANY)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        theme = ThemeManagementSupport.find!(guardian, arguments.fetch("theme_id"))
        name = arguments.fetch("name")
        setting = theme.settings[name.to_sym]
        raise Discourse::NotFound unless setting
        if arguments.fetch("operation") == "revert"
          ThemeManagementSupport.confirm!(arguments["confirm"])
          if arguments.key?("value")
            raise ToolError, I18n.t("mcp.errors.theme_setting_value_invalid")
          end
          value = setting.default
        else
          if !arguments.key?("value") || arguments["value"].nil?
            raise ToolError, I18n.t("mcp.errors.theme_setting_value_invalid")
          end
          value = arguments["value"]
          value = JSON.parse(value) if setting.type_name == :objects && value.is_a?(String)
          valid_type =
            case setting.type_name
            when :string
              value.is_a?(String)
            when :upload
              value.is_a?(String) || value.is_a?(Integer)
            else
              ThemeSettingsValidator.is_valid_value_type?(value, setting.type)
            end
          unless valid_type
            raise ToolError,
                  I18n.t("mcp.errors.theme_setting_type_invalid", name:, type: setting.type_name)
          end
        end
        ThemeSettingUpdater.update(guardian, theme, name, value)
        ToolHelpers.text_and_structured(name:, value: theme.reload.cached_settings[name.to_sym])
      rescue Discourse::NotFound
        raise ToolError, I18n.t("mcp.errors.theme_setting_not_found")
      rescue Discourse::InvalidParameters => error
        raise ToolError, error.message
      rescue JSON::ParserError
        raise ToolError, I18n.t("mcp.errors.theme_setting_value_invalid")
      end
    end

    class UpdateThemeTranslations
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(locale: OutputSchema::STRING, translations: OutputSchema::OBJECT_ARRAY)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        guardian.ensure_is_admin!
        locale = arguments.fetch("locale")
        if I18n.available_locales.exclude?(locale.to_sym)
          raise ToolError, I18n.t("errors.messages.invalid_locale", invalid_locale: locale)
        end
        I18n.with_locale(locale) do
          theme = ThemeManagementSupport.find!(guardian, arguments.fetch("theme_id"))
          ThemeManagementSupport.check_name!(theme, arguments.fetch("expected_name"))
          original = ThemeSerializer.new(theme, root: false).to_json
          ::Theme.transaction do
            ThemeTranslationUpdater.assign(guardian, theme, arguments.fetch("translations"))
            theme.save!
            StaffActionLogger.new(guardian.user).log_theme_change(original, theme)
          end
          ToolHelpers.text_and_structured(
            locale:,
            translations:
              theme.reload.translations.map do |entry|
                { key: entry.key, value: entry.value, default: entry.default }
              end,
          )
        end
      rescue Discourse::NotFound
        raise ToolError, I18n.t("mcp.errors.theme_translation_not_found")
      end
    end
  end
end
