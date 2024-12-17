# frozen_string_literal: true

module PageObjects
  module Components
    # TODO (martin) Delete this after plugins have been updated to use DPageHeader
    class AdminHeader < PageObjects::Pages::Base
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
