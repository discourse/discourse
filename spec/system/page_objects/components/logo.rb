# frozen_string_literal: true

module PageObjects
  module Components
    class Logo < PageObjects::Pages::Base
      SELECTOR = "#site-logo"

      def click
        browser_root.locator(".d-header .title a").filter(visible: true).click
      end

      def hover
        browser_root.locator(SELECTOR).filter(visible: true).hover
      end
    end
  end
end
