# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminFlags < AdminBase
      def visit
        browser_page
          .goto("/admin/config/flags")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def toggle(key)
        PageObjects::Components::DToggleSwitch.new(".admin-flag-item__toggle.#{key}").toggle
        has_saved_flag?(key)
        self
      end

      def toggle_flag_menu(key)
        browser_root.locator(".#{key} .flag-menu-trigger").filter(visible: true).click
        self
      end

      def has_action_for_flag?(flag)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".#{flag} .flag-menu-trigger").filter(visible: true),
        )
      end

      def has_no_action_for_flag?(flag)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".#{flag} .flag-menu-trigger").filter(visible: true),
        )
      end

      def has_disabled_edit_for_flag?(flag)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".#{flag} .admin-flag-item__edit[disabled]").filter(visible: true),
        )
      end

      def has_disabled_item_action?(action)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".admin-flag-item__#{action}[disabled]").filter(visible: true),
        )
      end

      def has_item_action?(action)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".admin-flag-item__#{action}").filter(visible: true),
        )
      end

      def has_no_item_action?(action)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".admin-flag-item__#{action}").filter(visible: true),
        )
      end

      def has_flags?(*flags)
        expect(
          browser_root
            .locator(".admin-flag-item__name")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |element| element.inner_text.strip },
        ).to eq(flags)
      end

      def has_add_flag_button_enabled?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".admin-flags__header-add-flag:not([disabled])").filter(
            visible: true,
          ),
        )
      end

      def has_add_flag_button_disabled?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".admin-flags__header-add-flag[disabled]").filter(visible: true),
        )
      end

      def has_flag?(flag)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".admin-flag-item.#{flag}").filter(visible: true),
        )
      end

      def has_no_flag?(flag)
        PlaywrightMatchers.have_count(
          0,
          timeout: (Capybara.default_max_wait_time * 3) * 1000,
        ).matches?(browser_root.locator(".admin-flag-item.#{flag}").filter(visible: true))
      end

      def has_saved_flag?(key)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".admin-flag-item.#{key}.saved").filter(visible: true),
        )
      end

      def has_closed_flag_menu?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".flag-menu-content").filter(visible: true),
        )
      end

      # Methods for when the enable_new_reordering_controls upcoming change is
      # enabled. move_up/move_down below keep main's menu-driven behaviour.
      #
      # TODO (ui-kit-reorderable-list-cleanup) fold these over them once the
      # change ships.
      def reorderable(key)
        PageObjects::Components::ReorderableList.new(reorderable_row_selector(key))
      end

      def move_up_via_list(key)
        reorderable(key).move(:up)
        self
      end

      def move_down_via_list(key)
        reorderable(key).move(:down)
        self
      end

      def move_to_top_via_list(key)
        reorderable(key).move(:top)
        self
      end

      # A real browser drag, the only move that can cross several rows without
      # naming a destination. The drop lands on the target's top edge.
      def drag_flag_above(source_key, target_key)
        drag_and_drop(
          source: "#{reorderable_row_selector(source_key)} .d-reorderable-list__handle",
          target: reorderable_row_selector(target_key),
          target_position: {
            x: 100,
            y: 1,
          },
        )
        self
      end

      # Waiting, unlike has_flags?, so it can follow a move or a page load.
      def has_flags_in_order?(*flags)
        PlaywrightMatchers.have_count(flags.size).matches?(
          browser_root.locator(".admin-flag-item__name").filter(visible: true),
        ) &&
          flags.each_with_index.all? do |flag, index|
            PlaywrightMatchers.contain_text(
              [browser_text_pattern(flag)],
              useInnerText: true,
            ).matches?(
              browser_root.locator(
                ".admin-flag-item:nth-child(#{index + 1}) .admin-flag-item__name",
              ).filter(visible: true),
            )
          end
      end

      def move_down(key)
        toggle_flag_menu(key)
        browser_root.locator(".admin-flag-item__move-down").filter(visible: true).click
        has_closed_flag_menu?
        self
      end

      def move_up(key)
        toggle_flag_menu(key)
        browser_root.locator(".admin-flag-item__move-up").filter(visible: true).click
        has_closed_flag_menu?
        self
      end

      def click_add_flag
        browser_root.locator(".admin-flags__header-add-flag").filter(visible: true).click
        self
      end

      def click_edit_flag(key)
        browser_root.locator(".#{key} .admin-flag-item__edit").filter(visible: true).click
        self
      end

      def click_delete_flag(key)
        browser_root.locator(".#{key} .flag-menu-trigger").filter(visible: true).click
        browser_root.locator(".admin-flag-item__delete").filter(visible: true).click
        self
      end

      def confirm_delete
        browser_root.locator(".dialog-footer .btn-primary").filter(visible: true).click
        expect(
          browser_root.locator(".dialog-body").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0, timeout: (Capybara.default_max_wait_time * 3) * 1000)
        self
      end

      private

      def reorderable_row_selector(key)
        ".admin-flag-item.#{key}"
      end
    end
  end
end
