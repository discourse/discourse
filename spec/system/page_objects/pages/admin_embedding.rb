# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmbedding < AdminBase
      def visit
        browser_page
          .goto("/admin/customize/embedding")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def click_add_host
        browser_root.locator(".admin-embedding__header-add-host").filter(visible: true).click
        self
      end

      def click_edit_host
        browser_root.locator(".admin-embeddable-host-item__edit").filter(visible: true).click
        self
      end

      def open_embedding_host_menu
        browser_root.locator(".embedding-host-menu-trigger").filter(visible: true).click
        self
      end

      def full_app_mode_toggle
        PageObjects::Components::DToggleSwitch.new(
          ".admin-embedding-index__full-app-toggle .d-toggle-switch__checkbox",
        )
      end

      def click_full_app_mode_toggle
        full_app_mode_toggle.toggle
        self
      end

      def has_full_app_mode_enabled?
        full_app_mode_toggle.checked?
      end

      def has_full_app_mode_disabled?
        full_app_mode_toggle.unchecked?
      end

      def expand_snippet
        browser_root
          .locator(".admin-embedding-index__code .admin-config-area-card__toggle-button")
          .filter(visible: true)
          .click
        self
      end

      def has_snippet_containing?(text)
        contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".admin-embedding-index__code code").filter(visible: true),
        )
      end

      def has_no_snippet_containing?(text)
        contain_text([browser_text_pattern(text)], useInnerText: true).does_not_match?(
          browser_root.locator(".admin-embedding-index__code code").filter(visible: true),
        )
      end

      def click_delete
        open_embedding_host_menu
        browser_root.locator(".admin-embeddable-host-item__delete").filter(visible: true).click
        self
      end

      def confirm_delete
        browser_root.locator(".dialog-footer .btn-primary").filter(visible: true).click
        expect(browser_root.locator(".dialog-body").filter(visible: true)).to have_count(
          0,
          timeout: (Capybara.default_max_wait_time * 3) * 1000,
        )
        self
      end
    end
  end
end
