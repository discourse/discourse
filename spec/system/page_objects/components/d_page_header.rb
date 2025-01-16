# frozen_string_literal: true

module PageObjects
  module Components
    class DPageHeader < PageObjects::Pages::Base
      def has_tabs?(names)
        expect(page.all("#{tabs_container_selector} a").map(&:text)).to eq(names)
      end

      def has_active_tab?(tab_name)
        find("#{tab_selector(tab_name)} .active")
      end

      def tab(tab_name)
        find(tab_selector(tab_name))
      end

      def visible?
        has_css?(".d-page-header")
      end

      def hidden?
        has_no_css?(".d-page-header")
      end

      private

      def tabs_container_selector
        "ul.d-nav-submenu__tabs"
      end

      def tab_item_selector(tab_name)
        "li[class$='-tabs__#{tab_name}']"
      end

      def tab_selector(tab_name)
        "#{tabs_container_selector} > #{tab_item_selector(tab_name)}"
      end
    end
  end
end
