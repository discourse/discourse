# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminFlags < PageObjects::Pages::Base
      def toggle(key)
        PageObjects::Components::DToggleSwitch.new(".admin-flag-item__toggle.#{key}").toggle
      end

      def open_flag_menu(key)
        find(".#{key} .flag-menu-trigger").click
      end

      def move_down(key)
        open_flag_menu(key)
        find(".admin-flag-item__move-down").click
      end

      def move_up(key)
        open_flag_menu(key)
        find(".admin-flag-item__move-up").click
      end

      def click_add_flag
        find(".admin-flags__header-add-flag").click
      end

      def click_edit_flag(key)
        find(".#{key} .admin-flag-item__edit").click
      end

      def click_delete_flag(key)
        find(".#{key} .flag-menu-trigger").click
        find(".admin-flag-item__delete").click
      end

      def confirm_delete
        find(".dialog-footer .btn-primary").click
      end
    end
  end
end
