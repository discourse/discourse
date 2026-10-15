# frozen_string_literal: true

module PageObjects
  module Pages
    class FinishInstallation < PageObjects::Pages::Base
      def visit_page
        @navigation_response =
          browser_page
            .goto("/finish-installation")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_register
        @navigation_response =
          browser_page
            .goto("/finish-installation/register")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_discourse_id_button?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern("Login with Discourse ID")],
          useInnerText: true,
        ).matches?(browser_root.locator(".finish-installation__discourse-id").filter(visible: true))
      end

      def has_no_discourse_id_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".finish-installation__discourse-id").filter(visible: true),
        )
      end

      def has_register_button?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern("Register")],
          useInnerText: true,
        ).matches?(browser_root.locator(".finish-installation__register").filter(visible: true))
      end

      def has_no_register_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".finish-installation__register").filter(visible: true),
        )
      end

      def has_error_message?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".alert-error").filter(visible: true),
        )
      end

      def has_no_error_message?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".alert-error").filter(visible: true),
        )
      end

      def error_message_text
        browser_root.locator(".alert-error").filter(visible: true).inner_text.strip
      end

      def click_login_with_discourse_id
        browser_root.locator(".finish-installation__discourse-id").filter(visible: true).click
        self
      end

      def has_register_form?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("form.wizard-container__fields").filter(visible: true),
        )
      end

      def has_no_register_form?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("form.wizard-container__fields").filter(visible: true),
        )
      end

      def has_no_emails_message?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("finish_installation.register.no_emails"))],
          useInnerText: true,
        ).matches?(browser_root.locator("p").filter(visible: true))
      end

      def has_access_denied?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".not-found-container").filter(visible: true),
        ) || @navigation_response&.status == 403
      end

      def fill_username(username)
        browser_root.locator("#username").filter(visible: true).fill(username)
        self
      end

      def fill_password(password)
        browser_root.locator("#password").filter(visible: true).fill(password)
        self
      end

      def select_email(email)
        browser_root.locator("#email").filter(visible: true).select_option(label: email)
        self
      end

      def submit
        browser_root.locator("input[type='submit']").filter(visible: true).click
        self
      end

      def has_username_error?(message = nil)
        field =
          browser_root
            .locator(".wizard-container__field")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern("Username"))
        return false if field.get_attribute("class").exclude?("invalid")
        return true if message.nil?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(message)],
          useInnerText: true,
        ).matches?(field.locator(".field-error-description").filter(visible: true))
      end

      def has_password_error?(message = nil)
        field =
          browser_root
            .locator(".wizard-container__field")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern("Password"))
        return false if field.get_attribute("class").exclude?("invalid")
        return true if message.nil?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(message)],
          useInnerText: true,
        ).matches?(field.locator(".field-error-description").filter(visible: true))
      end

      def has_no_field_errors?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".wizard-container__field.invalid").filter(visible: true),
        )
      end

      def container_padding
        computed_style(".wizard-container", "padding-top")
      end

      def redirected_to_confirm_email?
        PlaywrightMatchers.have_url("/finish-installation/confirm-email").matches?(browser_page)
      end

      private

      def computed_style(selector, property)
        browser_page.evaluate("function(arguments) { return #{<<~JS} }", arg: [])
          getComputedStyle(document.querySelector(#{selector.to_json}))
            .getPropertyValue(#{property.to_json})
        JS
      end
    end
  end
end
