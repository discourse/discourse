# frozen_string_literal: true

module PageObjects
  module Components
    class AdminHeader < PageObjects::Pages::Base
      def has_tabs?(names)
        expect(page.all(".admin-nav-submenu__tabs a").map(&:text)).to eq(names)
      end
    end
  end
end
