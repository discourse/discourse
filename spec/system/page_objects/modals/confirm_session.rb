# frozen_string_literal: true

module PageObjects
  module Modals
    class ConfirmSession < PageObjects::Pages::Base
      def click_forgot_password
        find(".confirm-session .confirm-session__reset-btn").click
        self
      end

      def has_forgot_password_email_sent?
        has_css?(".confirm-session .confirm-session__reset-email-sent")
      end

      def submit_password(password)
        find(".confirm-session input#password").fill_in(with: password)
        find(".confirm-session .btn-primary:not([disabled])").click
        self
      end
    end
  end
end
