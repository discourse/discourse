# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmbedding < AdminBase
      def visit
        page.visit("/admin/customize/embedding")
        self
      end

      def click_add_host
        find(".admin-embedding__header-add-host").click
        self
      end

      def click_edit_host
        find(".admin-embeddable-host-item__edit").click
        self
      end

      def open_embedding_host_menu
        find(".embedding-host-menu-trigger").click
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
        find(".admin-embedding-index__code .admin-config-area-card__toggle-button").click
        self
      end

      def has_snippet_containing?(text)
        page.has_css?(".admin-embedding-index__code code", text: text)
      end

      def has_no_snippet_containing?(text)
        page.has_no_css?(".admin-embedding-index__code code", text: text)
      end

      def click_delete
        open_embedding_host_menu
        find(".admin-embeddable-host-item__delete").click
        self
      end

      def confirm_delete
        find(".dialog-footer .btn-primary").click
        expect(page).to have_no_css(".dialog-body", wait: Capybara.default_max_wait_time * 3)
        self
      end
    end
  end
end
