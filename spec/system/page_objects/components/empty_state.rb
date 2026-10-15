# frozen_string_literal: true

module PageObjects
  module Components
    class EmptyState < PageObjects::Components::Base
      def has_cta_text?(text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".empty-state__cta").filter(visible: true),
        )
      end

      def click_cta
        browser_root.locator(".empty-state__cta").filter(visible: true).click
      end
    end
  end
end
