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

      def has_action_for_flag?(flag)
        has_selector?(".#{flag} .flag-menu-trigger")
      end

      def has_no_action_for_flag?(flag)
        has_no_selector?(".#{flag} .flag-menu-trigger")
      end

      def has_disabled_edit_for_flag?(flag)
        has_selector?(".#{flag} .admin-flag-item__edit[disabled]")
      end

      def has_disabled_item_action?(action)
        has_selector?(".admin-flag-item__#{action}[disabled]")
      end

      def has_disabled_delete_action?
        has_selector?(".admin-item__delete[disabled]")
      end

      def has_item_action?(action)
        has_selector?(".admin-flag-item__#{action}")
      end

      def has_no_item_action?(action)
        has_no_selector?(".admin-flag-item__#{action}")
      end

      def has_flags?(*flags)
        all(".admin-flag-item__name").map(&:text) == flags
      end

      def has_add_flag_button_enabled?
        has_css?(".admin-flags__header-add-flag:not([disabled])")
      end

      def has_add_flag_button_disabled?
        has_no_css?(".admin-flags__header-add-flag[disabled]")
      end

      def has_flag?(flag)
        has_css?(".admin-flag-item.#{flag}")
      end

      def has_no_flag?(flag)
        has_no_css?(".admin-flag-item.#{flag}", wait: Capybara.default_max_wait_time * 3)
      end

      def has_saved_flag?(key)
        has_css?(".admin-flag-item.#{key}.saved")
      end

      def has_closed_flag_menu?
        has_no_css?(".flag-menu-content")
      end

      def move_down(key)
        open_flag_menu(key)
        find(".admin-flag-item__move-down").click
        has_closed_flag_menu?
        self
      end

      def move_up(key)
        open_flag_menu(key)
        find(".admin-flag-item__move-up").click
        has_closed_flag_menu?
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
        find(".admin-item__delete").click
        self
      end

      def confirm_delete
        find(".dialog-footer .btn-primary").click
        expect(page).to have_no_css(".dialog-body", wait: Capybara.default_max_wait_time * 3)
        self
      end

      def click_settings_tab
        find(".admin-flags-tabs__settings a").click
        self
      end
    end
  end
end
