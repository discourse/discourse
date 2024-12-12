# frozen_string_literal: true

module PageObjects
  module Components
    class DPageHeader < PageObjects::Pages::Base
      def has_tabs?(names)
        expect(page.all(".d-nav-submenu__tabs a").map(&:text)).to eq(names)
      end

      def visible?
        has_css?(".d-page-header")
      end

      def hidden?
        has_no_css?(".d-page-header")
      end
    end
  end
end
