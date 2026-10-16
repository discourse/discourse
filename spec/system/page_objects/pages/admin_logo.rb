# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminLogo < PageObjects::Pages::Base
      def visit
        browser_page
          .goto("/admin/config/logo")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def form
        @form ||= PageObjects::Components::AdminLogoForm.new
      end
    end
  end
end
