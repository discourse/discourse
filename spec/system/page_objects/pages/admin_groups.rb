# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminGroups < AdminBase
      def visit
        browser_page.goto("/admin/groups").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def search(filter)
        browser_root.locator(".groups-header-filters input").filter(visible: true).fill(filter)
        self
      end

      def has_groups?(groups)
        PlaywrightMatchers.have_count(groups.length, timeout: 5 * 1000).matches?(
          browser_root.locator(".group-info-name").filter(visible: true),
        ) &&
          browser_root
            .locator(".group-info-name")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |element| element.inner_text.strip } == groups
      end

      def has_no_groups?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".group-info-name").filter(visible: true),
        )
      end
    end
  end
end
