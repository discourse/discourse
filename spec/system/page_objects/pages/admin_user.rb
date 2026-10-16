# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUser < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/admin/users/#{user.id}/#{user.username}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def click_action_logs_button
        browser_root
          .locator(
            "[id=#{I18n.t("admin_js.admin.user.action_logs").to_s.to_json}], [name=#{I18n.t("admin_js.admin.user.action_logs").to_s.to_json}]",
          )
          .or(browser_root.get_by_role("button", name: I18n.t("admin_js.admin.user.action_logs")))
          .filter(visible: true)
          .click
      end

      def has_suspend_button?
        have_count(0).does_not_match?(
          browser_root.locator(".btn-danger.suspend-user").filter(visible: true),
        )
      end

      def has_unsuspend_button?
        have_count(0).does_not_match?(
          browser_root.locator(".btn-danger.unsuspend-user").filter(visible: true),
        )
      end

      def has_no_suspend_button?
        have_count(0).matches?(
          browser_root.locator(".btn-danger.suspend-user").filter(visible: true),
        )
      end

      def has_silence_button?
        have_count(0).does_not_match?(
          browser_root.locator(".btn-danger.silence-user").filter(visible: true),
        )
      end

      def has_unsilence_button?
        have_count(0).does_not_match?(
          browser_root.locator(".btn-danger.unsilence-user").filter(visible: true),
        )
      end

      def has_no_silence_button?
        have_count(0).matches?(
          browser_root.locator(".btn-danger.silence-user").filter(visible: true),
        )
      end

      def has_change_trust_level_dropdown_enabled?
        have_count(0).does_not_match?(
          browser_root.locator(".change-trust-level-dropdown").filter(visible: true),
        ) &&
          have_count(0).matches?(
            browser_root.locator(".change-trust-level-dropdown.is-disabled").filter(visible: true),
          )
      end

      def has_change_trust_level_dropdown_disabled?
        have_count(0).does_not_match?(
          browser_root.locator(".change-trust-level-dropdown.is-disabled").filter(visible: true),
        )
      end

      def click_suspend_button
        browser_root.locator(".btn-danger.suspend-user").filter(visible: true).click
      end

      def click_unsuspend_button
        browser_root.locator(".btn-danger.unsuspend-user").filter(visible: true).click
      end

      def click_silence_button
        browser_root.locator(".btn-danger.silence-user").filter(visible: true).click
      end

      def click_unsilence_button
        browser_root.locator(".btn-danger.unsilence-user").filter(visible: true).click
      end

      def click_approve_button
        browser_root
          .locator(".display-row .controls .btn")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.user.approve")))
          .click
      end

      def has_approve_success?
        contain_text(
          [browser_text_pattern(I18n.t("admin_js.admin.user.approve_success"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".display-row .controls").filter(visible: true))
      end

      def custom_groups_chooser
        PageObjects::Components::SelectKit.new(".admin-user__custom-groups .group-chooser")
      end

      def save_custom_groups
        browser_root.locator(".admin-user__custom-groups .ok").filter(visible: true).click
      end

      def has_custom_groups_save_button?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-user__custom-groups .ok").filter(visible: true),
        )
      end

      def has_no_custom_groups_save_button?
        have_count(0).matches?(
          browser_root.locator(".admin-user__custom-groups .ok").filter(visible: true),
        )
      end

      def has_custom_group?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(".admin-user__custom-groups .formatted-selection").filter(
            visible: true,
          ),
        )
      end

      def has_no_custom_group?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).does_not_match?(
          browser_root.locator(".admin-user__custom-groups .formatted-selection").filter(
            visible: true,
          ),
        )
      end

      def similar_users_warning
        browser_root
          .locator(".penalty-similar-users .alert-warning")
          .filter(visible: true)
          .evaluate(
            "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
            arg: "innerHTML",
          )
      end

      def open_upcoming_changes_modal
        browser_root.locator(".upcoming-changes-info .btn-default").filter(visible: true).click
      end

      class UpcomingChangeRow < PageObjects::Components::Base
        attr_reader :element

        def initialize(element)
          @element = element
        end

        def enabled?
          expect(
            element
              .locator(".upcoming-change-enabled-status")
              .filter(visible: true)
              .locator(".emoji[alt='white_check_mark']")
              .filter(visible: true),
          ).not_to have_count(0)
        end

        def disabled?
          expect(
            element
              .locator(".upcoming-change-enabled-status")
              .filter(visible: true)
              .locator(".emoji[alt='cross_mark']")
              .filter(visible: true),
          ).not_to have_count(0)
        end

        def has_reason?(reason_key)
          expected_text = I18n.t("js.user.upcoming_changes.why_reasons.#{reason_key}")
          expect(element.locator(".upcoming-change-reason").filter(visible: true)).to contain_text(
            browser_text_pattern(expected_text),
            useInnerText: true,
          )
        end

        def specific_groups
          within_browser(element.locator(".upcoming-change-groups").filter(visible: true)) do
            browser_root
              .locator("a")
              .filter(visible: true)
              .tap { |elements| elements.first.wait_for(state: "visible") }
              .all
              .map { |element| element.inner_text.strip }
              .sort
          end
        end

        def has_specific_groups?(group_names)
          specific_groups == group_names.sort
        end

        def has_no_specific_groups?
          expect(
            element
              .tap do |parent|
                parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
              end
              .locator(".upcoming-change-groups")
              .filter(visible: true),
          ).to have_count(0)
        end
      end

      def has_upcoming_change?(change_name)
        have_count(0).does_not_match?(
          browser_root.locator(
            ".admin-user-upcoming-changes-modal .user-upcoming-changes-table .d-table__row[data-upcoming-change-name='#{change_name}']",
          ).filter(visible: true),
        )
      end

      def has_no_upcoming_change?(change_name)
        have_count(0).matches?(
          browser_root.locator(
            ".admin-user-upcoming-changes-modal .user-upcoming-changes-table .d-table__row[data-upcoming-change-name='#{change_name}']",
          ).filter(visible: true),
        )
      end

      def upcoming_change(change_name)
        row =
          browser_root.locator(
            ".admin-user-upcoming-changes-modal .user-upcoming-changes-table .d-table__row[data-upcoming-change-name='#{change_name}']",
          ).filter(visible: true)
        UpcomingChangeRow.new(row)
      end
    end
  end
end
