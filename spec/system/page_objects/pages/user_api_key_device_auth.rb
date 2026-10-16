# frozen_string_literal: true

module PageObjects
  module Pages
    class UserApiKeyDeviceAuth < PageObjects::Pages::Base
      def visit_activate(request_token: nil)
        path = "/user-api-key/activate"
        path = "#{path}?#{URI.encode_www_form(request: request_token)}" if request_token.present?

        browser_page.goto(path).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_authorization_details?(application_name:, scopes:, username:)
        contain_text([browser_text_pattern(application_name)], useInnerText: true).matches?(
          browser_root.locator(".authorize-api-key h1").filter(visible: true),
        ) &&
          contain_text([browser_text_pattern(username)], useInnerText: true).matches?(
            browser_root.locator(".authorize-api-key__username").filter(visible: true),
          ) &&
          scopes.all? do |scope|
            contain_text([browser_text_pattern(scope)], useInnerText: true).matches?(
              browser_root.locator(".authorize-api-key__scopes li").filter(visible: true),
            )
          end
      end

      def has_write_warning?
        contain_text(
          [browser_text_pattern(I18n.t("user_api_key.write_scope_warning"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".authorize-api-key__write-warning").filter(visible: true))
      end

      def has_unregistered_app_warning?
        contain_text(
          [browser_text_pattern(I18n.t("user_api_key.device.unregistered_app_warning"))],
          useInnerText: true,
        ).matches?(
          browser_root.locator(".authorize-api-key__unregistered-warning").filter(visible: true),
        )
      end

      def has_expiry_notice?(application_name:)
        contain_text([browser_text_pattern("Expires:")], useInnerText: true).matches?(
          browser_root.locator(".authorize-api-key__expiry").filter(visible: true),
        )
      end

      def enter_code(code)
        input = browser_root.locator("input.authorize-api-key__code-input").filter(visible: true)
        input.fill(code.delete("-"))
        browser_page.evaluate(
          "function(arguments) { arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true })); arguments[0].dispatchEvent(new Event('change', { bubbles: true })); }",
          arg: browser_arguments(input, code.delete("-")),
        )

        self
      end

      def click_continue
        browser_root
          .locator(
            "[id=#{I18n.t("user_api_key.device.continue").to_s.to_json}], [name=#{I18n.t("user_api_key.device.continue").to_s.to_json}]",
          )
          .or(browser_root.get_by_role("button", name: I18n.t("user_api_key.device.continue")))
          .filter(visible: true)
          .click
        self
      end

      def click_authorize
        if browser_root
             .locator(".authorize-api-key__buttons .btn-primary")
             .filter(visible: true)
             .filter(hasText: browser_text_pattern(I18n.t("user_api_key.authorize")))
             .count != 0
          browser_root
            .locator(".authorize-api-key__buttons .btn-primary")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(I18n.t("user_api_key.authorize")))
            .click
        else
          browser_root
            .locator(
              "[id=#{I18n.t("user_api_key.authorize").to_s.to_json}], [name=#{I18n.t("user_api_key.authorize").to_s.to_json}]",
            )
            .or(browser_root.get_by_role("button", name: I18n.t("user_api_key.authorize")))
            .filter(visible: true)
            .click
        end
        self
      end

      def has_invalid_code_message?
        contain_text(
          [browser_text_pattern(I18n.t("user_api_key.device.invalid_code"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".form-kit__errors").filter(visible: true))
      end

      def has_completion_message?
        contain_text(
          [browser_text_pattern(I18n.t("user_api_key.device.complete"))],
          useInnerText: true,
          timeout: 10 * 1000,
        ).matches?(browser_root.locator(".authorize-api-key h1").filter(visible: true)) &&
          contain_text(
            [browser_text_pattern(I18n.t("user_api_key.device.return_to_cli"))],
            useInnerText: true,
          ).matches?(browser_root.locator(".authorize-api-key p").filter(visible: true))
      end
    end
  end
end
