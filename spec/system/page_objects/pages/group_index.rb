# frozen_string_literal: true

module PageObjects
  module Pages
    class GroupIndex < PageObjects::Pages::Base
      def visit
        browser_page.goto("/groups").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def click_new_group
        browser_root.locator(".groups-header-new").filter(visible: true).click
        self
      end
    end
  end
end
