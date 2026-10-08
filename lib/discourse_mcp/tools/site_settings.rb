# frozen_string_literal: true

module DiscourseMcp
  module Tools
    module SiteSettingSupport
      CREDENTIAL_NAME =
        /(?:\A|_)(?:secret|token|password|passphrase|private_key|access_keys?|api_keys?|credentials?)(?:\z|_)/i
      UNSUPPORTED_TYPES = %w[upload uploaded_image_list uploaded-image-list objects].freeze
      UPDATE_POLICIES = %i[
        settings_are_not_deprecated
        settings_are_unshadowed_globally
        settings_are_visible
        settings_are_configurable
      ].freeze

      module_function

      def ensure_admin!(guardian)
        guardian.ensure_is_admin!
      end

      def settings(arguments = {}, include_hidden: false)
        SiteSetting.all_settings(
          include_hidden:,
          filter_categories: arguments["categories"],
          filter_plugin: arguments["plugin"],
          filter_names: arguments["names"],
        )
      end

      def exact_setting(name)
        settings({ "names" => [name] }).reverse.find { |setting| setting[:setting].to_s == name }
      end

      def blocked?(setting)
        setting[:secret] || setting[:setting].to_s.match?(CREDENTIAL_NAME)
      end

      def unsupported_type?(setting)
        setting[:themeable] == true || UNSUPPORTED_TYPES.include?(setting[:type].to_s)
      end

      def project(setting)
        blocked = blocked?(setting)
        {
          setting: setting[:setting].to_s,
          humanized_name: setting[:humanized_name].to_s.first(500),
          description: setting[:description].to_s.first(4_000),
          category: setting[:category],
          primary_area: setting[:primary_area],
          plugin: setting[:plugin],
          type: setting[:type].to_s,
          value: blocked ? nil : setting[:value],
          default: blocked ? nil : setting[:default],
          secret: blocked,
          overridden: setting[:value].to_s != setting[:default].to_s,
          valid_values: bounded_collection(setting[:valid_values]),
          min: setting[:min],
          max: setting[:max],
          mandatory_values: bounded_collection(setting[:mandatory_values]),
          requires_confirmation: setting[:requires_confirmation].present?,
          depends_on: Array(setting[:depends_on]).first(50).map(&:to_s),
          depends_behavior: setting[:depends_behavior]&.to_s,
          depends_on_values: bounded_hash(setting[:depends_on_values]),
          themeable: setting[:themeable] == true,
          editable_by_this_tool: !blocked && !unsupported_type?(setting),
        }
      end

      def bounded_collection(value)
        return [] if !value.is_a?(Array)

        value
          .first(200)
          .map do |item|
            if item.is_a?(Hash)
              item
                .slice(:id, :name, :value, "id", "name", "value")
                .transform_values { |entry| entry.to_s.first(1_000) }
            else
              item.to_s.first(1_000)
            end
          end
      end

      def bounded_hash(value)
        return {} if !value.is_a?(Hash)

        value
          .first(50)
          .to_h do |key, item|
            [key.to_s.first(200), Array(item).first(50).map { |entry| entry.to_s.first(1_000) }]
          end
      end

      def normalize(value)
        case value
        when Array
          value.map(&:to_s).join("|")
        when TrueClass
          "true"
        when FalseClass
          "false"
        else
          value.to_s
        end
      end

      def serialize(value)
        value.is_a?(Array) ? value.map(&:to_s).join("|") : value
      end

      def ensure_dependencies!(setting)
        dependencies = Array(setting[:depends_on]).map(&:to_s)
        return {} if dependencies.empty?

        definitions =
          settings({ "names" => dependencies }, include_hidden: true).index_by do |item|
            item[:setting].to_s
          end
        allowed_values = setting[:depends_on_values].is_a?(Hash) ? setting[:depends_on_values] : {}
        unsatisfied =
          dependencies.reject do |name|
            definition = definitions[name]
            next false if definition.blank?

            allowed = allowed_values[name] || allowed_values[name.to_sym]
            if allowed
              Array(allowed).map(&:to_s).include?(definition[:value].to_s)
            else
              %w[true 1 yes].include?(definition[:value].to_s.downcase)
            end
          end
        if unsatisfied.present?
          raise ToolError,
                I18n.t("mcp.errors.site_setting_dependency", settings: unsatisfied.join(", "))
        end

        dependencies.to_h { |name| [name, definitions.fetch(name)[:value]] }
      end

      def update!(guardian, setting_name, value, expected_values:)
        result =
          SiteSetting::Update.call(
            guardian:,
            params: {
              settings: [{ setting_name:, value: serialize(value) }],
            },
            options: {
              expected_values:,
            },
          )
        return if result.success?

        if result["result.try.default"]&.exception.is_a?(SiteSetting::Update::Conflict)
          raise ToolError, I18n.t("mcp.errors.site_setting_conflict")
        end

        raise ToolError, update_error(result)
      rescue Discourse::InvalidParameters => error
        raise ToolError, error.message
      end

      def update_error(result)
        contract = result["result.contract.default"]
        return contract.errors.full_messages.to_sentence if contract&.failure?

        UPDATE_POLICIES.each do |policy_name|
          policy = result["result.policy.#{policy_name}"]
          return policy.reason if policy&.failure? && policy.reason.present?
        end
        result["result.step.save"]&.exception&.message.presence ||
          I18n.t("mcp.errors.site_setting_update_failed")
      end
    end

    class ListSiteSettings
      REQUIRED_SCOPES = [Scopes::SITE_SETTINGS_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(site_settings: OutputSchema::OBJECT_ARRAY, meta: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        SiteSettingSupport.ensure_admin!(request_context.guardian)
        offset = arguments.fetch("offset", 0)
        limit = arguments.fetch("limit", 100)
        requested_names = Array(arguments["names"]).to_set
        rows =
          SiteSettingSupport
            .settings(arguments)
            .select do |setting|
              requested_names.empty? || requested_names.include?(setting[:setting].to_s)
            end
        if arguments["overridden_only"]
          rows.select! { |setting| setting[:value].to_s != setting[:default].to_s }
        end
        page = rows.slice(offset, limit) || []
        has_more = offset + page.length < rows.length
        ToolHelpers.text_and_structured(
          site_settings: page.map { |setting| SiteSettingSupport.project(setting) },
          meta: {
            offset:,
            limit:,
            returned: page.length,
            total: rows.length,
            overridden_only: arguments.fetch("overridden_only", false),
            has_more:,
            next_offset: has_more ? offset + page.length : nil,
          },
        )
      end
    end

    class UpdateSiteSetting
      REQUIRED_SCOPES = [Scopes::SITE_SETTINGS_WRITE].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          updated: OutputSchema::BOOLEAN,
          setting: OutputSchema::STRING,
          operation: OutputSchema::STRING,
          before: OutputSchema::OBJECT,
          after: OutputSchema::OBJECT,
          verified: OutputSchema::BOOLEAN,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        SiteSettingSupport.ensure_admin!(guardian)
        if arguments["confirm_change"] != true
          raise ToolError, I18n.t("mcp.errors.site_setting_change_confirmation_required")
        end
        setting_name = arguments.fetch("setting")
        setting = SiteSettingSupport.exact_setting(setting_name)
        raise ToolError, I18n.t("mcp.errors.site_setting_not_found") if setting.blank?
        if SiteSettingSupport.blocked?(setting)
          raise ToolError, I18n.t("mcp.errors.site_setting_sensitive")
        end
        if SiteSettingSupport.unsupported_type?(setting)
          raise ToolError, I18n.t("mcp.errors.site_setting_type_unsupported")
        end

        expected_values = SiteSettingSupport.ensure_dependencies!(setting)
        expected = SiteSettingSupport.normalize(arguments.fetch("expected_current_value"))
        if expected != SiteSettingSupport.normalize(setting[:value])
          raise ToolError, I18n.t("mcp.errors.site_setting_conflict")
        end
        if setting[:requires_confirmation].present? && !arguments["confirm_required_setting"]
          raise ToolError, I18n.t("mcp.errors.site_setting_confirmation_required")
        end

        operation = arguments.fetch("operation")
        value =
          case operation
          when "set"
            if !arguments.key?("value")
              raise ToolError, I18n.t("mcp.errors.site_setting_value_required")
            end
            arguments["value"]
          when "reset_to_default"
            if arguments.key?("value")
              raise ToolError, I18n.t("mcp.errors.site_setting_value_forbidden")
            end
            setting[:default]
          end
        if SiteSettingSupport.normalize(value) == SiteSettingSupport.normalize(setting[:value])
          raise ToolError, I18n.t("mcp.errors.site_setting_no_change")
        end

        before = SiteSettingSupport.project(setting)
        SiteSettingSupport.update!(
          guardian,
          setting_name,
          value,
          expected_values: expected_values.merge(setting_name => setting[:value]),
        )
        after_setting = SiteSettingSupport.exact_setting(setting_name)
        if after_setting.blank?
          raise ToolError, I18n.t("mcp.errors.site_setting_verification_failed")
        end
        if SiteSettingSupport.normalize(after_setting[:value]) ==
             SiteSettingSupport.normalize(setting[:value])
          raise ToolError, I18n.t("mcp.errors.site_setting_no_change")
        end

        ToolHelpers.text_and_structured(
          updated: true,
          setting: setting_name,
          operation:,
          before:,
          after: SiteSettingSupport.project(after_setting),
          verified: true,
        )
      end
    end
  end
end
