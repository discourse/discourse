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
    end
  end
end
