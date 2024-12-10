# frozen_string_literal: true

module PageObjects
  module Components
    class AdminHeader < PageObjects::Pages::Base
      def has_tabs?(names)
        expect(page.all(".admin-nav-submenu__tabs a").map(&:text)).to eq(names)
      end

      def visible?
        has_css?(".admin-page-header")
      end

      def hidden?
        has_no_css?(".admin-page-header")
      end
    end
  end
end
