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
        page.driver.with_playwright_page do |browser|
          browser.locator("[data-name='category'] .form-kit__control-menu-trigger").click
          browser.get_by_role("button", name: "Choose for me", exact: true).click
        end
        self
      end
    end
  end
end
