# frozen_string_literal: true

module DiscourseMcp
  module Tools
    module ThemeSupport
      ASSIGNABLE_FIELDS = %w[
        name
        color_scheme_id
        dark_color_scheme_id
        user_selectable
        enabled
        auto_update
      ].freeze
      # Mirrors Theme.targets / ThemeField.types; inlined so registration does not
      # depend on app autoloading during boot.
      TARGETS = %w[
        common
        desktop
        mobile
        settings
        translations
        extra_scss
        extra_js
        tests_js
        migrations
        about
      ].freeze
      FIELD_TYPES = %w[
        html
        scss
        theme_upload_var
        theme_color_var
        theme_var
        yaml
        js
        theme_screenshot_upload_var
        json
      ].freeze

      module_function

      def ensure_admin!(guardian)
        guardian.ensure_is_admin!
      end

      def normalize_fields(fields)
        Array(fields).map do |field|
          normalized =
            field.slice("name", "target", "value", "type", "type_id", "upload_id").compact_blank
          normalized["value"] = field["value"] if field.key?("value")
          if normalized["type"].present? && !ThemeField.types.key?(normalized["type"].to_sym)
            raise ToolError, I18n.t("mcp.errors.theme_field_type_invalid", type: normalized["type"])
          end
          if field.key?("value") && !field["value"].is_a?(String)
            raise ToolError,
                  I18n.t("mcp.errors.theme_field_value_required", name: normalized["name"])
          end
          type_id =
            normalized["type_id"] ||
              (ThemeField.types[normalized["type"].to_sym] if normalized["type"].present?) ||
              ThemeField.guess_type(name: normalized["name"], target: normalized["target"])
          upload_field = [
            ThemeField.types[:theme_upload_var],
            ThemeField.types[:theme_screenshot_upload_var],
          ].include?(type_id)

          if normalized["upload_id"].present?
            if normalized["value"].present?
              raise ToolError, I18n.t("mcp.errors.theme_field_source_conflict")
            end
            unless upload_field
              raise ToolError,
                    I18n.t("mcp.errors.theme_inline_field_upload", name: normalized["name"])
            end
            unless Upload.exists?(id: normalized["upload_id"])
              raise ToolError, I18n.t("mcp.errors.theme_field_upload_not_found")
            end
          elsif !normalized.key?("value")
            raise ToolError,
                  I18n.t("mcp.errors.theme_field_value_required", name: normalized["name"])
          end

          if normalized["value"].present? && type_id && Theme.targets[normalized["target"]&.to_sym]
            candidate =
              ThemeField.new(
                name: normalized["name"],
                target_id: Theme.targets[normalized["target"].to_sym],
                type_id: type_id,
              )
            if [
                 ThemeField.types[:html],
                 ThemeField.types[:scss],
                 ThemeField.types[:js],
                 ThemeField.types[:yaml],
                 ThemeField.types[:json],
               ].include?(type_id) && candidate.file_path.nil?
              raise ToolError, I18n.t("mcp.errors.theme_field_location_invalid")
            end
          end

          normalized
        end
      end

      # Theme settings can name categories and tags: list settings of those
      # types, and objects settings with categories or tags properties. While a
      # rule narrows topics, a setting that names a restricted one in its value
      # or default has both left out.
      def redact_setting(setting, json, policy)
        return json if !policy.restricts_forum?

        restricted =
          [json[:value], json[:default]].any? do |value|
            restricted_setting_value?(setting, value, policy)
          end
        restricted ? json.merge(value: nil, default: nil, redacted: true) : json
      end

      def restricted_setting_value?(setting, value, policy)
        return false if value.blank?

        case setting.type_name
        when :list
          items = value.to_s.split("|")
          case setting.list_type
          when "category"
            items.any? { |id| !policy.allows_category_id?(id.to_i) }
          when "tag"
            items.any? { |name| !policy.allows_tag?(name) }
          else
            false
          end
        when :objects
          objects = Array(value).select { |object| object.is_a?(Hash) }
          objects = objects.map { |object| object.deep_stringify_keys.with_indifferent_access }
          schema = setting.schema.deep_symbolize_keys
          category_ids =
            SchemaSettingsObjectValidator.property_values_of_type(
              schema:,
              objects:,
              type: "categories",
            )
          tags =
            SchemaSettingsObjectValidator.property_values_of_type(schema:, objects:, type: "tags")
          category_ids.any? { |id| !policy.allows_category_id?(id.to_i) } ||
            tags.any? do |tag|
              if tag.is_a?(Integer)
                policy.restricted_tag_ids.include?(tag)
              else
                !policy.allows_tag?(tag)
              end
            end
        else
          false
        end
      end

      def theme_json(theme, policy)
        {
          id: theme.id,
          name: theme.name,
          component: theme.component,
          enabled: theme.enabled,
          activation: {
            applies_to_default_theme:
              (
                if theme.component?
                  theme.enabled? && theme.parent_theme_ids.include?(SiteSetting.default_theme_id)
                else
                  theme.default?
                end
              ),
            note:
              "Enabled does not mean applied. Components must be attached to a theme; standalone themes must be default or selected by a user. Browser appearance is not verified.",
          },
          user_selectable: theme.user_selectable,
          color_scheme_id: theme.color_scheme_id,
          dark_color_scheme_id: theme.dark_color_scheme_id,
          default: theme.default?,
          remote_theme_id: theme.remote_theme_id,
          child_theme_ids: theme.child_theme_ids,
          parent_theme_ids: theme.parent_theme_ids,
          created_at: theme.created_at.iso8601,
          updated_at: theme.updated_at.iso8601,
          theme_fields: theme.theme_fields.map { |field| theme_field_json(field) },
          code_revision: code_revision(theme),
          settings:
            theme.settings.values.map do |setting|
              redact_setting(
                setting,
                ThemeSettingsSerializer.new(setting, root: false).as_json,
                policy,
              )
            end,
          translations:
            theme.translations.map do |translation|
              { key: translation.key, value: translation.value, default: translation.default }
            end,
        }
      end

      def theme_field_json(field)
        {
          name: field.name,
          target: ::Theme.lookup_target(field.target_id)&.to_s,
          type_id: field.type_id,
          value: field.value,
          upload_id: field.upload_id,
          error: field.error.presence,
          file_path: field.file_path,
        }
      end

      def code_revision(theme)
        Digest::SHA256.hexdigest(
          theme
            .theme_fields
            .reorder(:id)
            .pluck(:target_id, :name, :type_id, :value, :upload_id)
            .to_json,
        )
      end

      def raise_create_failure!(result)
        if result["result.policy.ensure_remote_themes_are_not_allowlisted"]&.failure?
          raise Discourse::InvalidAccess
        end

        contract = result["result.contract.default"]
        raise ToolError, contract.errors.full_messages.to_sentence if contract&.failure?

        model_failure = result["result.model.theme"]
        raise ToolError, model_failure.exception.message if model_failure&.exception

        theme = result[:theme]
        raise ToolError, theme.errors.full_messages.join(", ") if theme&.errors.present?

        raise ToolError, I18n.t("mcp.errors.theme_create_failed")
      end

      def ensure_fields_editable!(theme)
        raise Discourse::InvalidAccess if !::Theme.allowed_remote_theme_ids.nil?
        raise Discourse::InvalidAccess if theme.remote_theme&.is_git?
      end
    end

    class SetThemeCode
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      CONTENT = {
        topics: :unenforced,
        private_messages: :unenforced,
        categories: :unenforced,
        tags: :unenforced,
        exit_paths: :unenforced,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(theme: OutputSchema::OBJECT, verification: OutputSchema::OBJECT)
      JAVASCRIPT_NAME = "discourse/api-initializers/mcp-theme-code.js"

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        guardian.ensure_is_admin!
        theme = Theme.find_by(id: arguments.fetch("theme_id"))
        raise ToolError, I18n.t("mcp.errors.theme_not_found") unless theme
        guardian.ensure_can_edit_theme!(theme)
        ThemeSupport.ensure_fields_editable!(theme)
        provided = %w[css javascript].select { |key| arguments.key?(key) }
        raise ToolError, I18n.t("mcp.errors.theme_code_required") if provided.empty?
        provided.each do |key|
          unless arguments[key].is_a?(String) && arguments[key].length <= 65_536
            raise ToolError, I18n.t("mcp.errors.theme_code_too_large")
          end
        end

        Theme.transaction do
          theme.lock!
          unless arguments["expected_code_revision"] == ThemeSupport.code_revision(theme)
            raise ToolError, I18n.t("mcp.errors.theme_code_stale")
          end
          fields = []
          if provided.include?("css")
            fields << { "target" => "common", "name" => "scss", "value" => arguments["css"] }
          end
          if provided.include?("javascript")
            fields << {
              "target" => "extra_js",
              "name" => JAVASCRIPT_NAME,
              "value" => arguments["javascript"],
            }
          end
          UpdateTheme.call(
            arguments: {
              "theme_id" => theme.id,
              "theme_fields" => fields,
            },
            request_context: request_context,
          )
          theme.reload
          if provided.include?("css") && arguments["css"].present?
            theme
              .theme_fields
              .find_by!(target_id: Theme.targets[:common], name: "scss")
              .compile_scss
          end
          if provided.include?("javascript") && (javascript = theme.load_all_extra_js).present?
            compiler = ThemeJavascriptCompiler.new(theme.id, theme.name, minify: false)
            compiler.append_tree(javascript)
            if error = compiler.error
              raise ToolError, I18n.t("mcp.errors.theme_code_js_invalid", message: error.message)
            end
          end
          ToolHelpers.text_and_structured(
            theme: ThemeSupport.theme_json(theme, request_context.content_policy),
            verification: {
              saved: true,
              compilation_checked: true,
              browser_verified: false,
              note:
                "Saved and compilation checked; this does not verify selectors, imports in other files, or rendered browser behavior.",
            },
          )
        end
      rescue SassC::SyntaxError, SassC::NotRenderedError, AssetProcessor::TranspileError => error
        raise ToolError, I18n.t("mcp.errors.theme_code_compile_failed", message: error.message)
      end
    end

    class GetTheme
      REQUIRED_SCOPES = [Scopes::THEMES_READ].freeze
      CONTENT = {
        topics: :untouched,
        private_messages: :untouched,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema.object(theme: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        ThemeSupport.ensure_admin!(request_context.guardian)
        theme = ::Theme.include_relations.find_by(id: arguments.fetch("theme_id"))
        raise ToolError, I18n.t("mcp.errors.theme_not_found") if theme.blank?

        ToolHelpers.text_and_structured(
          theme: ThemeSupport.theme_json(theme, request_context.content_policy),
        )
      end
    end

    class CreateTheme
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      CONTENT = {
        topics: :unenforced,
        private_messages: :unenforced,
        categories: :unenforced,
        tags: :unenforced,
        exit_paths: :unenforced,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema.object(theme: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        guardian.ensure_can_create_theme!

        result =
          Themes::Create.call(
            guardian:,
            params: {
              name: arguments.fetch("name"),
              user_id: request_context.user_id,
              user_selectable: arguments.fetch("user_selectable", false),
              color_scheme_id: arguments["color_scheme_id"],
              component: arguments.fetch("component", false),
              default: arguments.fetch("default", false),
              theme_fields: ThemeSupport.normalize_fields(arguments["theme_fields"]),
            },
          )

        ThemeSupport.raise_create_failure!(result) if result.failure?

        ToolHelpers.text_and_structured(
          theme: ThemeSupport.theme_json(result.theme, request_context.content_policy),
        )
      end
    end

    class UpdateTheme
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      CONTENT = {
        topics: :unenforced,
        private_messages: :unenforced,
        categories: :unenforced,
        tags: :unenforced,
        exit_paths: :unenforced,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema.object(theme: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ThemeSupport.ensure_admin!(guardian)

        theme = ::Theme.include_relations.find_by(id: arguments.fetch("theme_id"))
        raise ToolError, I18n.t("mcp.errors.theme_not_found") if theme.blank?

        guardian.ensure_can_edit_theme!(theme)
        child_theme_ids = arguments["child_theme_ids"]
        parent_theme_ids = arguments["parent_theme_ids"]
        if arguments.key?("component") && arguments["component"] != theme.component?
          if arguments["component"]
            child_theme_ids = []
          else
            parent_theme_ids = []
          end
        end
        if !guardian.can_edit_theme_relations?(
             theme,
             child_theme_ids: child_theme_ids,
             parent_theme_ids: parent_theme_ids,
           )
          raise Discourse::InvalidAccess
        end

        ensure_system_theme_editable!(theme, arguments)
        if arguments.keys == ["theme_id"]
          raise ToolError, I18n.t("mcp.errors.theme_update_required")
        end

        if arguments["default"] && arguments.fetch("component", theme.component?)
          raise ToolError, I18n.t("themes.errors.component_no_default")
        end

        original_json = ThemeSerializer.new(theme, root: false).to_json
        ::Theme.transaction do
          if arguments.key?("component") && arguments["component"] != theme.component?
            raise ToolError, I18n.t("themes.errors.component_no_default") if theme.default?
            if arguments["component"]
              theme.switch_to_component!
            else
              theme.switch_to_theme!
            end
            theme.reload
            guardian.ensure_can_edit_theme!(theme)
          end
          assign_changes(theme, arguments)
          if !theme.save
            raise ToolError,
                  theme.errors.full_messages.join(", ").presence ||
                    I18n.t("mcp.errors.theme_update_failed")
          end

          apply_default(theme, arguments)
          theme = ::Theme.include_relations.find(theme.id)
          logger = StaffActionLogger.new(guardian.user)
          logger.log_theme_change(original_json, theme)
          if theme.component? && arguments.key?("enabled")
            if theme.enabled?
              logger.log_theme_component_enabled(theme)
            else
              logger.log_theme_component_disabled(theme)
            end
          end
        end

        ToolHelpers.text_and_structured(
          theme: ThemeSupport.theme_json(theme, request_context.content_policy),
        )
      rescue Discourse::InvalidParameters,
             ::Theme::InvalidFieldTargetError,
             ::Theme::InvalidFieldTypeError => error
        raise ToolError, error.message.presence || I18n.t("mcp.errors.theme_update_failed")
      end

      def self.ensure_system_theme_editable!(theme, arguments)
        return if !theme.system?

        requested = arguments.keys - %w[theme_id]
        raise Discourse::InvalidAccess if (requested - ::Theme::EDITABLE_SYSTEM_ATTRIBUTES).present?
      end
      private_class_method :ensure_system_theme_editable!

      def self.assign_changes(theme, arguments)
        ThemeSupport::ASSIGNABLE_FIELDS.each do |field|
          theme.public_send("#{field}=", arguments[field]) if arguments.key?(field)
        end

        if arguments.key?("child_theme_ids")
          ids = arguments["child_theme_ids"]
          if ids.present? &&
               (theme.component? || Theme.where(id: ids, component: true).count != ids.uniq.length)
            raise ToolError, I18n.t("mcp.errors.theme_children_must_be_components")
          end
          theme.child_theme_ids = ids
        end
        if arguments.key?("parent_theme_ids")
          ids = arguments["parent_theme_ids"]
          if ids.present? &&
               (
                 !theme.component? ||
                   Theme.where(id: ids, component: false).count != ids.uniq.length
               )
            raise ToolError, I18n.t("mcp.errors.theme_parents_must_be_themes")
          end
          theme.parent_theme_ids = ids
        end

        return if !arguments.key?("theme_fields")

        ThemeSupport.ensure_fields_editable!(theme)
        ThemeSupport
          .normalize_fields(arguments["theme_fields"])
          .each do |field|
            theme.set_field(
              target: field.fetch("target"),
              name: field.fetch("name"),
              value: field["value"],
              type: field["type"],
              type_id: field["type_id"],
              upload_id: field["upload_id"],
            )
          end
      end
      private_class_method :assign_changes

      def self.apply_default(theme, arguments)
        return if !arguments.key?("default")

        if arguments["default"]
          theme.set_default!
        elsif theme.default?
          ::Theme.clear_default!
        end
      end
      private_class_method :apply_default
    end
  end
end
