# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUser < PageObjects::Pages::Base
      def visit(user)
        page.visit("/admin/users/#{user.id}/#{user.username}")
      end

      def click_action_logs_button
        click_button(I18n.t("admin_js.admin.user.action_logs"))
      end

      def has_suspend_button?
        has_css?(".btn-danger.suspend-user")
      end

      def has_no_suspend_button?
        has_no_css?(".btn-danger.suspend-user")
      end

      def has_silence_button?
        has_css?(".btn-danger.silence-user")
      end

      def has_no_silence_button?
        has_no_css?(".btn-danger.silence-user")
      end

      def has_change_trust_level_dropdown_enabled?
        has_css?(".change-trust-level-dropdown") &&
          has_no_css?(".change-trust-level-dropdown.is-disabled")
      end

      def has_change_trust_level_dropdown_disabled?
        has_css?(".change-trust-level-dropdown.is-disabled")
      end

      def click_suspend_button
        find(".btn-danger.suspend-user").click
      end

      def click_unsuspend_button
        find(".btn-danger.unsuspend-user").click
      end

      def click_silence_button
        find(".btn-danger.silence-user").click
      end

      def click_unsilence_button
        find(".btn-danger.unsilence-user").click
      end

      def similar_users_warning
        find(".penalty-similar-users .alert-warning")["innerHTML"]
      end

      class UpcomingChangeRow < PageObjects::Components::Base
        attr_reader :element

        def initialize(element)
          @element = element
        end

        def enabled?
          expect(element.find(".upcoming-change-enabled-status")).to have_content(
            I18n.t("js.yes_value"),
          )
        end

        def disabled?
          expect(element.find(".upcoming-change-enabled-status")).to have_content(
            I18n.t("js.no_value"),
          )
        end

        def has_reason?(reason_key)
          expected_text = I18n.t("js.user.upcoming_changes.why_reasons.#{reason_key}")
          expect(element.find(".upcoming-change-reason")).to have_content(expected_text)
        end

        def specific_groups
          within element.find(".upcoming-change-groups") do
            all("a").map(&:text).sort
          end
        end

        def has_specific_groups?(group_names)
          specific_groups == group_names.sort
        end

        def has_no_specific_groups?
          expect(element).to have_no_css(".upcoming-change-groups")
        end
      end

      def has_upcoming_change?(change_name)
        has_css?(
          ".user-upcoming-changes-table .d-table__row[data-upcoming-change-name='#{change_name}']",
        )
      end

      def has_no_upcoming_change?(change_name)
        has_no_css?(
          ".user-upcoming-changes-table .d-table__row[data-upcoming-change-name='#{change_name}']",
        )
      end

      def upcoming_change(change_name)
        row =
          find(
            ".user-upcoming-changes-table .d-table__row[data-upcoming-change-name='#{change_name}']",
          )
        UpcomingChangeRow.new(row)
      end
    end
  end
end
