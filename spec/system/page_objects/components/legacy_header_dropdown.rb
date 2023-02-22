# frozen_string_literal: true

module PageObjects
  module Components
    class LegacyHeaderDropdown < PageObjects::Components::Base
      def click
        page.find(".hamburger-dropdown").click
      end

      def visible?
        page.has_css?(".menu-container-general-links")
      end
    end
  end
end
