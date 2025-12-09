# frozen_string_literal: true

module PageObjects
  module Pages
    class FinishInstallation < PageObjects::Pages::Base
      def visit_page
        page.visit("/finish-installation")
        self
      end

      def has_discourse_id_button?
        page.has_css?(".finish-installation__discourse-id", text: "Login with Discourse ID")
      end

      def has_no_discourse_id_button?
        page.has_no_css?(".finish-installation__discourse-id")
      end

      def has_register_button?
        page.has_css?(".finish-installation__register", text: "Register")
      end

      def has_no_register_button?
        page.has_no_css?(".finish-installation__register")
      end

      def has_error_message?
        page.has_css?(".alert-error")
      end

      def has_no_error_message?
        page.has_no_css?(".alert-error")
      end

      def error_message_text
        find(".alert-error").text
      end
    end
  end
end
