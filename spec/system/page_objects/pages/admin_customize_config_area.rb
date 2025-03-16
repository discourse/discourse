# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeConfigArea < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/customize")
      end

      def visit_components
        page.visit("/admin/config/customize/components")
      end

      def install_card
        find(".theme-install-card")
      end
    end
  end
end
