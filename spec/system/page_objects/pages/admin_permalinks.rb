# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminPermalinks < AdminBase
      def visit
        browser_page
          .goto("/admin/config/permalinks")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def toggle(key)
        PageObjects::Components::DToggleSwitch.new(".admin-flag-item__toggle.#{key}").toggle
        has_saved_flag?(key)
        self
      end

      def click_add_permalink
        browser_root.locator(".admin-permalinks__header-add-permalink").filter(visible: true).click
        self
      end

      def click_edit_permalink(url)
        browser_root.locator("tr.#{url} .admin-permalink-item__edit").filter(visible: true).click
        self
      end

      def click_delete_permalink(url)
        open_permalink_menu(url)
        browser_root.locator(".admin-permalink-item__delete").filter(visible: true).click
        browser_root.locator(".dialog-footer .btn-danger").filter(visible: true).click
        expect(
          browser_root.locator(".dialog-body").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0)
        has_closed_permalink_menu?
        self
      end

      def has_permalinks?(*permalinks)
        browser_root
          .locator(".admin-permalink-item__url")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |element| element.inner_text.strip } == permalinks
      end

      def has_no_permalinks?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".admin-permalink-item__url").filter(visible: true),
        )
      end

      def has_no_filter?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".d-filter-controls__input").filter(visible: true),
        )
      end

      def has_filter?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".d-filter-controls__input").filter(visible: true),
        )
      end

      def filter(text)
        browser_root.locator(".d-filter-controls__input").filter(visible: true).fill(text)
      end

      def has_no_results?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".d-filter-controls__no-results").filter(visible: true),
        )
      end

      def open_permalink_menu(url)
        browser_root.locator("tr.#{url} .permalink-menu-trigger").filter(visible: true).click
        self
      end

      def has_closed_permalink_menu?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".permalink-menu-content").filter(visible: true),
        )
      end
    end
  end
end
