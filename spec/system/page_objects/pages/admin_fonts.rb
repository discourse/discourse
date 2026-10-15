# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminFonts < PageObjects::Pages::Base
      def visit
        browser_page
          .goto("/admin/config/fonts")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def form
        @form ||= PageObjects::Components::AdminFontsForm.new
      end
    end
  end
end
