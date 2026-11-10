# frozen_string_literal: true

module PageObjects
  module Components
    class AiDsaClassificationSuggestion < PageObjects::Components::Base
      def suggest_rule
        find("[data-name='community_rule'] .form-kit__control-menu-trigger").click
        click_button("Choose for me", exact: true)
        self
      end

      def suggest_category
        find("[data-name='category'] .form-kit__control-menu-trigger").click
        click_button("Choose for me", exact: true)
        self
      end
    end
  end
end
