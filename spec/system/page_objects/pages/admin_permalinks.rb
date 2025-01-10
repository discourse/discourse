# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminPermalinks < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/permalinks")
        self
      end

      def toggle(key)
        PageObjects::Components::DToggleSwitch.new(".admin-flag-item__toggle.#{key}").toggle
        has_saved_flag?(key)
        self
      end

      def click_add_permalink
        find(".admin-permalinks__header-add-permalink").click
        self
      end

      def click_edit_permalink(url)
        find("tr.#{url} .admin-permalink-item__edit").click
        self
      end

      def click_delete_permalink(url)
        open_permalink_menu(url)
        find(".admin-permalink-item__delete").click
        find(".dialog-footer .btn-primary").click
        expect(page).to have_no_css(".dialog-body")
        has_closed_permalink_menu?
        self
      end

      def has_permalinks?(*permalinks)
        all(".admin-permalink-item__url").map(&:text) == permalinks
      end

      def has_no_permalinks?
        has_no_css?(".admin-permalink-item__url")
      end

      def has_no_filter?
        has_no_css?(".permalink-search")
      end

      def has_filter?
        has_css?(".permalink-search")
      end

      def filter(text)
        find(".permalink-search").fill_in with: text
      end

      def has_no_results?
        has_css?(".permalink-results__no-result")
      end

      def open_permalink_menu(url)
        find("tr.#{url} .permalink-menu-trigger").click
        self
      end

      def has_closed_permalink_menu?
        has_no_css?(".permalink-menu-content")
      end

      def click_tab(tab)
        has_css?(".admin-permalinks-tabs__#{tab}")
        find(".admin-permalinks-tabs__#{tab}").click
      end

      def has_active_tab?(tab)
        has_css?(".admin-permalinks-tabs__#{tab} .active")
      end
    end
  end
end
