# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBase < Base
      def click_tab(tab_name)
        header.tab(tab_name).click
      end

      delegate(:has_tabs?, :has_active_tab?, to: :header)

      private

      def header
        @header ||= Components::DPageHeader.new
      end
    end
  end
end
