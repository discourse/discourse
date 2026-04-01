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

      def click_full_app_mode_toggle
        find(".admin-embedding-index__full-app-toggle .d-toggle-switch__checkbox").click
        self
      end

      def has_full_app_mode_enabled?
        find(
          ".admin-embedding-index__full-app-toggle .d-toggle-switch__checkbox[aria-checked='true']",
        ).present?
      end

      def has_full_app_mode_disabled?
        find(
          ".admin-embedding-index__full-app-toggle .d-toggle-switch__checkbox[aria-checked='false']",
        ).present?
      end

      def has_snippet_containing?(text)
        if page.has_css?(".admin-embedding-index__code.-collapsed")
          find(".admin-embedding-index__code").click
        end
        find(".highlighted-code", text: text).present?
      end

      def has_no_snippet_containing?(text)
        if page.has_css?(".admin-embedding-index__code.-collapsed")
          find(".admin-embedding-index__code").click
        end
        page.has_no_css?(".highlighted-code", text: text)
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
