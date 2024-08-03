# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminFlags < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/flags")
        self
      end

      def toggle(key)
        PageObjects::Components::DToggleSwitch.new(".admin-flag-item__toggle.#{key}").toggle
        has_saved_flag?(key)
        self
      end

      def open_flag_menu(key)
        find(".#{key} .flag-menu-trigger").click
        self
      end

      def has_flags?(*flags)
        all(".admin-flag-item__name").map(&:text) == flags
      end

      def has_flag?(flag)
        has_css?(".admin-flag-item.#{flag}")
      end

      def has_no_flag?(flag)
        has_no_css?(".admin-flag-item.#{flag}")
      end

      def has_saved_flag?(key)
        has_css?(".admin-flag-item.#{key}.saving")
        has_no_css?(".admin-flag-item.#{key}.saving")
      end

      def move_down(key)
        open_flag_menu(key)
        find(".admin-flag-item__move-down").click
        has_saved_flag?(key)
        self
      end

      def move_up(key)
        open_flag_menu(key)
        find(".admin-flag-item__move-up").click
        has_saved_flag?(key)
        self
      end

      def click_add_flag
        find(".admin-flags__header-add-flag").click
        self
      end

      def click_edit_flag(key)
        find(".#{key} .admin-flag-item__edit").click
        self
      end

      def click_delete_flag(key)
        find(".#{key} .flag-menu-trigger").click
        find(".admin-flag-item__delete").click
        self
      end

      def confirm_delete
        find(".dialog-footer .btn-primary").click
        self
      end
    end
  end
end
