# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminLogo < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/logo")
      end

      def form
        @form ||= PageObjects::Components::AdminLogoForm.new
      end
    end
  end
end
