# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBranding < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/branding")
      end

      def logo_form
        @logo_form ||= PageObjects::Components::AdminBrandingLogoForm.new
      end

      def fonts_form
        @fonts_form ||= PageObjects::Components::AdminBrandingFontsForm.new
      end
    end
  end
end
