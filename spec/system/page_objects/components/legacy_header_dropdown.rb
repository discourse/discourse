# frozen_string_literal: true

module PageObjects
  module Components
    class LegacyHeaderDropdown < PageObjects::Components::Base
      def click
        page.find(".hamburger-dropdown").click
      end

      def visible?
        page.has_css?(".menu-panel.drop-down")
      end
    end
  end
end
