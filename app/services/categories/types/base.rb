# frozen_string_literal: true

module Categories
  module Types
    class Base
      class << self
        def type_id(id = nil)
          if id
            @type_id = id.to_sym
          else
            @type_id || name.demodulize.underscore.to_sym
          end
        end

        def enable_plugin
        end

        def configure_site_settings(category, configuration_values: {})
          configuration_schema[:site_settings]&.each do |setting_name, default_value|
            value = configuration_values.fetch(setting_name.to_s, default_value)
            SiteSetting.public_send("#{setting_name}=", value)
          end
        end

        def configure_category(category, configuration_values: {})
        end

        def configuration_schema
          {}
        end

        def available?
          true
        end

        def icon
          "comments"
        end

        def metadata
          {
            id: type_id,
            name: I18n.t("category_types.#{type_id}.name", default: type_id.to_s.titleize),
            description: I18n.t("category_types.#{type_id}.description", default: ""),
            icon: icon,
            available: available?,
            configuration_schema: resolved_configuration_schema,
          }
        end

        private

        def resolved_configuration_schema
          schema = configuration_schema
          return [] if schema.blank?

          entries = []

          schema[:site_settings]&.each do |setting_name, target_value|
            meta = SiteSetting.setting_metadata_hash(setting_name)
            entries << {
              key: setting_name.to_s,
              default: target_value,
              type: meta[:type],
              label: meta[:humanized_name],
              description: meta[:description],
            }
          end

          schema[:category_settings]&.each do |field_name, config|
            entries << {
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
