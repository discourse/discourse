# frozen_string_literal: true

module Categories
  module Types
    class Base
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
        def category_matches?(category)
          raise NotImplementedError
        end

        # Use this to enable any related plugin for the category type,
        # since we register category types without the plugin being enabled.
        def enable_plugin
        end

        # Configure any category-specific settings or custom fields that are
        # specific to this category type.
        def configure_category(category, guardian:, configuration_values: {})
        end

        # TODO (martin) Add docs for the schema/maybe a schema validator?
        def configuration_schema
          {}
        end

        # Used as an extension point to limit access to a category type
        # based on certain conditions, mostly for Discourse hosting.
        def available?
          true
        end

        def icon
          "memo"
        end

        # Configure any site settings that are specific to this category type.
        # The configuration schema must be defined for this, as it is also used
        # to show related settings in the UI for the category creator based
        # on type.
        #
        # This SHOULD NOT be overridden by category types.
        def configure_site_settings(category, guardian:, configuration_values: {})
          category_type_settings =
            configuration_schema[:site_settings].map do |setting_name, default_value|
              {
                setting_name: setting_name.to_s,
                value: configuration_values.fetch(setting_name.to_s, default_value),
              }
            end

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
          }
        end

        private

        def resolved_configuration_schema
          schema = configuration_schema
          return [] if schema.blank?

          entries = { site_settings: [], category_settings: [], category_custom_fields: [] }

          schema[:site_settings]&.each do |setting_name, target_value|
            meta = SiteSetting.setting_metadata_hash(setting_name)
            entries[:site_settings] << {
              key: setting_name.to_s,
              default: target_value,
              current: SiteSetting.public_send(setting_name),
              type: meta[:type],
              label: meta[:humanized_name],
              description: meta[:description],
            }
          end

          schema[:category_settings]&.each do |field_name, config|
            entries[:category_settings] << {
              key: field_name.to_s,
              default: config[:default],
              type: config[:type].to_s,
              label: config[:label],
              description: config[:description],
            }
          end

          schema[:category_custom_fields]&.each do |field_name, config|
            entries[:category_custom_fields] << {
              key: field_name.to_s,
              default: config[:default],
              type: config[:type].to_s,
              label: config[:label],
              description: config[:description],
            }
          end

          entries
        end
      end
    end
  end
end
