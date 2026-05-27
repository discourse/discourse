# frozen_string_literal: true

module PageObjects
  module Pages
    class FinishInstallation < PageObjects::Pages::Base
      def visit_page
        page.visit("/finish-installation")
        self
      end

      def visit_register
        visit("/finish-installation/register")
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

      def click_login_with_discourse_id
        find(".finish-installation__discourse-id").click
        self
      end

      def has_register_form?
        has_css?("form.wizard-container__fields")
      end

      def has_no_register_form?
        has_no_css?("form.wizard-container__fields")
      end

      def has_no_emails_message?
        has_css?("p", text: I18n.t("finish_installation.register.no_emails"))
      end

      def has_access_denied?
        has_css?(".not-found-container") || page.status_code == 403
      end

      def fill_username(username)
        find("#username").fill_in(with: username)
        self
      end

      def fill_password(password)
        find("#password").fill_in(with: password)
        self
      end

      def select_email(email)
        find("#email").select(email)
        self
      end

      def submit
        find("input[type='submit']").click
        self
      end

      def has_username_error?(message = nil)
        field = find(".wizard-container__field", text: "Username")
        return false if field[:class].exclude?("invalid")
        return true if message.nil?
        field.has_css?(".field-error-description", text: message)
      end

      def has_password_error?(message = nil)
        field = find(".wizard-container__field", text: "Password")
        return false if field[:class].exclude?("invalid")
        return true if message.nil?
        field.has_css?(".field-error-description", text: message)
      end

      def has_no_field_errors?
        has_no_css?(".wizard-container__field.invalid")
      end

      def redirected_to_confirm_email?
        has_current_path?("/finish-installation/confirm-email")
      end
    end
  end
end
