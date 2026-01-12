# frozen_string_literal: true

module Categories
  module Types
    class Docs < Base
      class << self
        def available?
          defined?(DiscourseDocs) && SiteSetting.respond_to?(:docs_enabled)
        end

        def enable_plugin
          SiteSetting.docs_enabled = true
        end

        def configure_site_settings(category)
          add_to_setting_list(:docs_categories, category.id)
        end

        def icon
          "book"
        end
      end
    end
  end
end
