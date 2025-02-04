# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUser < PageObjects::Pages::Base
      def visit(user)
        page.visit("/admin/users/#{user.id}/#{user.username}")
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

      def click_suspend_button
        find(".btn-danger.suspend-user").click
      end

      def click_silence_button
        find(".btn-danger.silence-user").click
      end

      def similar_users_warning
        find(".penalty-similar-users .alert-warning")["innerHTML"]
      end
    end
  end
end
