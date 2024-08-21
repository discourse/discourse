# frozen_string_literal: true

module PageObjects
  module Pages
    class InviteForm < PageObjects::Pages::Base
      def open(key)
        visit "/invites/#{key}"
      end

      def fill_username(username)
        find("#new-account-username").fill_in(with: username)
      end

      def fill_password(password)
        find("#new-account-password").fill_in(with: password)
      end

      def has_valid_username?
        find(".username-input").has_css?("#username-validation.good")
      end

      def has_valid_password?
        find(".password-input").has_css?("#password-validation.good")
      end

      def has_valid_fields?
        has_valid_username?
        has_valid_password?
      end

      def click_create_account
        find(".invitation-cta__accept.btn-primary").click
      end

      def has_successful_message?
        has_css?(".invite-success")
      end
    end
  end
end
