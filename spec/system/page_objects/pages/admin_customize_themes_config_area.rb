# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeThemesConfigArea < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/customize")
      end

      def install_card
        find(".theme-install-card")
      end
    end
  end
end
