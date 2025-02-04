# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBranding < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/branding")
      end
    end
  end
end
