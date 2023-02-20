# frozen_string_literal: true

module PageObjects
  module Components
    class SidebarHeaderDropdown < PageObjects::Components::Base
      def click
        page.find(".hamburger-dropdown").click
      end

      def visible?
        page.has_css?(".revamped.menu-panel.drop-down")
      end
    end
  end
end
