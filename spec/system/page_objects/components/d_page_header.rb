# frozen_string_literal: true

module PageObjects
  module Components
    class DPageHeader < PageObjects::Pages::Base
      def has_tabs?(names)
        expect(page.all(".d-nav-submenu__tabs a").map(&:text)).to eq(names)
      end
    end
  end
end
