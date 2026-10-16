# frozen_string_literal: true

module PageObjects
  module Components
    class TopicQueryFilter < PageObjects::Components::Base
      def fill_in(text)
        browser_root
          .locator(".topic-query-filter__filter-term")
          .filter(visible: true)
          .fill("#{text}\n")
        browser_page.keyboard.press("Enter")
      end

      def has_input_text?(text)
        have_value(text).matches?(
          browser_root
            .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
            .and(browser_root.locator(".#{"topic-query-filter__filter-term".to_s.split.join(".")}"))
            .filter(visible: true),
        )
      end
    end
  end
end
