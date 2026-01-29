# frozen_string_literal: true

module Categories
  module Types
    class Support < Base
      class << self
        def available?
          defined?(DiscourseSolved) && SiteSetting.respond_to?(:solved_enabled)
        end

        def enable_plugin
          SiteSetting.solved_enabled = true
        end

        def configure_category(category)
          category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
          category.save_custom_fields
        end

        def icon
          "square-check"
        end
      end
    end
  end
end
