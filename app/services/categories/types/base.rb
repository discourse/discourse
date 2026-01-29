# frozen_string_literal: true

module Categories
  module Types
    class Base
      class << self
        # Whether this type is available (plugin installed and accessible)
        def available?
          true
        end

        # Enable the required plugin(s) site-wide if not already enabled
        def enable_plugin
          # Override in subclasses
        end

        # Configure site settings (e.g., add category to a list setting)
        def configure_site_settings(category)
          # Override in subclasses
        end

        # Configure category-specific settings (custom fields, etc.)
        def configure_category(category)
          # Override in subclasses
        end

        # The unique identifier for this type
        def type_id
          name.demodulize.underscore.to_sym
        end

        # The icon to display for this type
        def icon
          "comments"
        end

        # Metadata for serialization
        def metadata
          {
            id: type_id,
            name: I18n.t("category_types.#{type_id}.name", default: type_id.to_s.titleize),
            description: I18n.t("category_types.#{type_id}.description", default: ""),
            icon: icon,
            available: available?,
          }
        end

        protected

        # Helper to add a category ID to a pipe-separated site setting list
        def add_to_setting_list(setting_name, category_id)
          current = SiteSetting.public_send(setting_name).to_s.split("|").reject(&:blank?)
          return if current.include?(category_id.to_s)

          current << category_id.to_s
          SiteSetting.public_send("#{setting_name}=", current.join("|"))
        end
      end
    end
  end
end
