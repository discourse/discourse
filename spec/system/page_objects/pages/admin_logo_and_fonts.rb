# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminLogoAndFonts < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/logo-and-fonts")
      end

      def logo_form
        @logo_form ||= PageObjects::Components::AdminLogoForm.new
      end

      def fonts_form
        @fonts_form ||= PageObjects::Components::AdminFontsForm.new
      end
    end
  end
end
