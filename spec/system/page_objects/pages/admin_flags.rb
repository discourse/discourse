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
        find(".dropdown-menu__item .move-down").click
      end

      def move_up(key)
        open_flag_menu(key)
        find(".dropdown-menu__item .move-up").click
      end
    end
  end
end
