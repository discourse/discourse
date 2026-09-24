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
          field.slice("name", "target", "value", "type", "type_id", "upload_id").compact_blank
        end
      end

      def theme_json(theme)
        {
          id: theme.id,
          name: theme.name,
          component: theme.component,
          enabled: theme.enabled,
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
        }
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

    class GetTheme
      REQUIRED_SCOPES = [Scopes::THEMES_READ].freeze
      OUTPUT_SCHEMA = OutputSchema.object(theme: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        ThemeSupport.ensure_admin!(request_context.guardian)
        theme = ::Theme.include_relations.find_by(id: arguments.fetch("theme_id"))
        raise ToolError, I18n.t("mcp.errors.theme_not_found") if theme.blank?

        ToolHelpers.text_and_structured(theme: ThemeSupport.theme_json(theme))
      end
    end

    class CreateTheme
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
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

        ToolHelpers.text_and_structured(theme: ThemeSupport.theme_json(result.theme))
      end
    end

    class UpdateTheme
      REQUIRED_SCOPES = [Scopes::THEMES_WRITE].freeze
      OUTPUT_SCHEMA = OutputSchema.object(theme: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ThemeSupport.ensure_admin!(guardian)

        theme = ::Theme.include_relations.find_by(id: arguments.fetch("theme_id"))
        raise ToolError, I18n.t("mcp.errors.theme_not_found") if theme.blank?

        ensure_system_theme_editable!(theme, arguments)
        if arguments.keys == ["theme_id"]
          raise ToolError, I18n.t("mcp.errors.theme_update_required")
        end

        if arguments["default"] && theme.component?
          raise ToolError, I18n.t("themes.errors.component_no_default")
        end

        original_json = ThemeSerializer.new(theme, root: false).to_json
        ::Theme.transaction do
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

        ToolHelpers.text_and_structured(theme: ThemeSupport.theme_json(theme))
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

        theme.child_theme_ids = arguments["child_theme_ids"] if arguments.key?("child_theme_ids")
        theme.parent_theme_ids = arguments["parent_theme_ids"] if arguments.key?("parent_theme_ids")

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
