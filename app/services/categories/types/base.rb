# frozen_string_literal: true

module Categories
  module Types
    class Base
      CONFIGURATION_SCHEMA_DEFINITION = {
        "type" => "object",
        "additionalProperties" => false,
        "properties" => {
          "general_category_settings" => {
            "type" => "object",
            "additionalProperties" => {
              "$ref" => "#/$defs/field_config",
            },
          },
          "site_settings" => {
            "type" => "object",
          },
          "category_custom_fields" => {
            "type" => "object",
            "additionalProperties" => {
              "$ref" => "#/$defs/field_config",
            },
          },
          "category_settings" => {
            "type" => "object",
            "additionalProperties" => {
              "$ref" => "#/$defs/field_config",
            },
          },
        },
        "$defs" => {
          "field_config" => {
            "type" => "object",
            "required" => %w[default type label],
            "additionalProperties" => false,
            "properties" => {
              "default" => true,
              "type" => {
                "type" => "string",
                "minLength" => 1,
              },
              "label" => {
                "type" => "string",
                "minLength" => 1,
              },
              "description" => {
                "type" => "string",
              },
              "show_on_create" => {
                "type" => "boolean",
              },
              "show_on_edit" => {
                "type" => "boolean",
              },
            },
          },
        },
      }.freeze

      class << self
        # Every category type must have a unique type_id.
        def type_id(id = nil)
          if id
            @type_id = id.to_sym
          else
            @type_id || name.demodulize.underscore.to_sym
          end
        end

        # Returns true if the category provided is of this type,
        # based on settings, category attributes, etc.
        #
        # This MUST be overridden by category types.
        def category_matches?(category)
          raise NotImplementedError
        end

        # Use this to enable any related plugin for the category type,
        # since we register category types without the plugin being enabled.
        #
        # This SHOULD be overridden by category types if they are related to a plugin.
        def enable_plugin
        end

        # Configure any category-specific settings or custom fields that are
        # specific to this category type.
        #
        # This SHOULD be overridden by category types.
        def configure_category(category, guardian:, configuration_values: {})
        end

        # Returns a hash describing the configuration schema for this category type.
        # This schema drives both the UI (what settings are shown to admins in the
        # category creator) and the site-setting update allowlist.
        #
        # The hash MAY include any subset of the following top-level keys.
        # All top-level keys are optional; an empty hash is valid.
        #
        #   {
        #     general_category_settings: {
        #       # Used to prefill basic category fields when creating a new category.
        #       # Each key is the category field name (Symbol).
        #       # Each value is a config Hash:
        #       #   default:     (required) Any value; the field's default when creating a new category.
        #       #   type:        (required) Symbol — e.g. :integer, :string, :boolean, matching site setting types.
        #       name: {
        #         value: "My Category",
        #         type: :string,
        #       },
        #       style_type: {
        #         value: "emoji",
        #         type: :string,
        #       },
        #       emoji: {
        #         value: "🔥",
        #         type: :string,
        #       },
        #     },
        #
        #     site_settings: {
        #       # Each key must be a valid SiteSetting name.
        #       # The value is the desired default to apply when this category type is configured.
        #       show_filter_by_solved_status: true,
        #     },
        #
        #     category_custom_fields: {
        #       # Each key is the custom field name (Symbol).
        #       # Each value is a config Hash:
        #       #   default:     (required) Any value; the field's default.
        #       #   type:        (required) Symbol — e.g. :integer, :string, :boolean, matching site setting types.
        #       #   label:       (required) String — FormKit label shown in UI
        #       #   description: (optional) String — FormKit description/help text shown in UI
        #       #   show_on_create: (optional) Boolean — Whether to show the field on category creation. Defaults to true.
        #       #   show_on_edit: (optional) Boolean — Whether to show the field on category edit. Defaults to true.
        #       solved_topics_auto_close_hours: {
        #         default: 48,
        #         type: :integer,
        #         label: "Auto-close after solved (hours)",
        #         description: "Close topics this many hours after being solved.",
        #       },
        #     },
        #
        #     category_settings: {
        #       # Same structure as category_custom_fields above.
        #     },
        #   }
        #
        # Use +validate_schema!+ to verify a schema conforms to this contract.
        def configuration_schema
          {}
        end

        # Validates the hash returned by +configuration_schema+ using JSONSchemer.
        # Raises +ArgumentError+ with a descriptive message if invalid.
        # Also validates that any site_settings keys are real SiteSettings (a
        # runtime check that cannot be expressed in JSON Schema).
        def validate_schema!
          # Normalize Ruby symbol keys/values to strings via JSON round-trip
          schema_as_json = JSON.parse(configuration_schema.to_json)

          schemer = JSONSchemer.schema(CONFIGURATION_SCHEMA_DEFINITION)
          errors = schemer.validate(schema_as_json).to_a
          if errors.any?
            messages = errors.map { |err| JSONSchemer::Errors.pretty(err) }.join("; ")
            raise ArgumentError, "#{name}#configuration_schema is invalid: #{messages}"
          end

          # Validate site_settings keys are real SiteSettings (runtime check)
          schema_as_json["site_settings"]&.each_key do |setting_name|
            unless SiteSetting.has_setting?(setting_name)
              raise ArgumentError,
                    "#{name}#configuration_schema[:site_settings] references unknown SiteSetting: #{setting_name.inspect}"
            end
          end
        end

        # Used as an extension point to limit access to a category type
        # based on certain conditions, mostly for Discourse hosting.
        def available?
          true
        end

        # Also used as an extension point to add additional keys/values to
        # the metadata hash returned by +metadata+, mostly for Discourse hosting.
        def additional_metadata
          {}
        end

        def icon
          "memo"
        end

        # Configure any custom fields that are specific to this category type,
        # should be called from within +configure_category+ for each type.
        #
        # This SHOULD NOT be overridden by category types.
        def configure_custom_fields(category, guardian:, configuration_values: {})
          configuration_schema[:category_custom_fields]&.each do |field_name, config|
            value = configuration_values.fetch(field_name.to_s, config[:default])
            category.custom_fields[field_name.to_s] = value
          end

          category.save_custom_fields
        end

        # Configure any site settings that are specific to this category type.
        # The configuration schema must be defined for this, as it is also used
        # to show related settings in the UI for the category creator based
        # on type.
        #
        # This SHOULD NOT be overridden by category types.
        def configure_site_settings(category, guardian:, configuration_values: {})
          category_type_settings =
            configuration_schema[:site_settings]&.map do |setting_name, default_value|
              {
                setting_name: setting_name.to_s,
                value: configuration_values.fetch(setting_name.to_s, default_value),
              }
            end

          return if category_type_settings.blank?

          # We do this because we want to allow updating hidden settings for the
          # category type, but not other settings. The configuration schema for
          # a category type defines which settings it wants to change, so that's
          # a good source to use as an allowlist here.
          allowed_setting_names = category.category_type_site_setting_names
          SiteSetting::Update.call(
            guardian:,
            options: {
              allow_changing_hidden: allowed_setting_names,
            },
            params: {
              settings: category_type_settings,
            },
          )
        end

        # Used when serializing the category configuration schema to the client.
        def metadata
          name = I18n.t("category_types.#{type_id}.name", default: type_id.to_s.titleize)
          {
            id: type_id,
            name: name,
            title: I18n.t("category_types.#{type_id}.title", default: name),
            description: I18n.t("category_types.#{type_id}.description", default: ""),
            icon:,
            available: available?,
            configuration_schema: resolved_configuration_schema,
          }.merge(additional_metadata)
        end

        private

        def resolved_configuration_schema
          schema = configuration_schema
          return {} if schema.blank?

          entries = {
            general_category_settings: [],
            site_settings: [],
            category_settings: [],
            category_custom_fields: [],
          }

          schema[:general_category_settings]&.each do |setting_name, config|
            entries[:general_category_settings] << {
              key: setting_name.to_s,
              default: config[:default],
              type: config[:type].to_s,
              required: config[:required],
              show_on_create: config[:show_on_create].nil? ? true : config[:show_on_create],
              show_on_edit: config[:show_on_edit].nil? ? true : config[:show_on_edit],
            }
          end

          schema[:site_settings]&.each do |setting_name, target_value|
            meta = SiteSetting.setting_metadata_hash(setting_name)
            entries[:site_settings] << {
              key: setting_name.to_s,
              default: target_value,
              current: SiteSetting.public_send(setting_name),
              type: meta[:type],
              label: meta[:humanized_name],
              description: meta[:description],
              required: false,
              show_on_create: true,
              show_on_edit: true,
            }
          end

          schema[:category_settings]&.each do |field_name, config|
            entries[:category_settings] << {
              key: field_name.to_s,
              default: config[:default],
              type: config[:type].to_s,
              label: config[:label],
              description: config[:description],
              required: config[:required],
              show_on_create: config[:show_on_create].nil? ? true : config[:show_on_create],
              show_on_edit: config[:show_on_edit].nil? ? true : config[:show_on_edit],
            }
          end

          schema[:category_custom_fields]&.each do |field_name, config|
            entries[:category_custom_fields] << {
              key: field_name.to_s,
              default: config[:default],
              type: config[:type].to_s,
              label: config[:label],
              description: config[:description],
              required: config[:required],
              show_on_create: config[:show_on_create].nil? ? true : config[:show_on_create],
              show_on_edit: config[:show_on_edit].nil? ? true : config[:show_on_edit],
            }
          end

          entries
        end
      end
    end
  end
end
