# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminFonts < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/fonts")
      end

      def form
        @form ||= PageObjects::Components::AdminFontsForm.new
      end
    end
  end
end
