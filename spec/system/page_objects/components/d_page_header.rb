# frozen_string_literal: true

module PageObjects
  module Components
    class DPageHeader < PageObjects::Pages::Base
      def has_tabs?(names)
        expect(
          browser_root
            .locator("#{tabs_container_selector} a")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |element| element.inner_text.strip },
        ).to eq(names)
      end

      def has_tab?(tab_name)
        have_count(0).does_not_match?(
          browser_root.locator(tab_selector(tab_name)).filter(visible: true),
        )
      end

      def has_no_tab?(tab_name)
        have_count(0).matches?(browser_root.locator(tab_selector(tab_name)).filter(visible: true))
      end

      def has_active_tab?(tab_name)
        have_count(0).does_not_match?(
          browser_root.locator("#{tab_selector(tab_name)} .active").filter(visible: true),
        )
      end

      def tab(tab_name)
        browser_root.locator(tab_selector(tab_name)).filter(visible: true)
      end

      def visible?
        have_count(0).does_not_match?(browser_root.locator(".d-page-header").filter(visible: true))
      end

      def hidden?
        have_count(0).matches?(browser_root.locator(".d-page-header").filter(visible: true))
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
