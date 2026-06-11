# frozen_string_literal: true

module PageObjects
  module Pages
    class UserApiKeyDeviceAuth < PageObjects::Pages::Base
      def visit_activate(request_token: nil)
        path = "/user-api-key/activate"
        path = "#{path}?#{URI.encode_www_form(request: request_token)}" if request_token.present?

        page.visit(path)
        self
      end

      def has_authorization_details?(application_name:, scopes:, username:)
        has_css?(".authorize-api-key h1", text: application_name) &&
          has_css?(".authorize-api-key__username", text: username) &&
          scopes.all? { |scope| has_css?(".authorize-api-key__scopes li", text: scope) }
      end

      def has_write_warning?
        has_css?(
          ".authorize-api-key__write-warning",
          text: I18n.t("user_api_key.write_scope_warning"),
        )
      end

      def has_unregistered_app_warning?
        has_css?(
          ".authorize-api-key__unregistered-warning",
          text: I18n.t("user_api_key.device.unregistered_app_warning"),
        )
      end

      def has_expiry_notice?(application_name:)
        has_css?(".authorize-api-key__expiry", text: "Expires:")
      end

      def enter_code(code)
        input = find("input.authorize-api-key__code-input")
        input.fill_in(with: code.delete("-"))
        page.execute_script(
          "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true })); arguments[0].dispatchEvent(new Event('change', { bubbles: true }));",
          input.native,
          code.delete("-"),
        )

        self
      end

      def click_continue
        click_button(I18n.t("user_api_key.device.continue"))
        self
      end

      def click_authorize
        if has_css?(
             ".authorize-api-key__buttons .btn-primary",
             text: I18n.t("user_api_key.authorize"),
             wait: 0,
           )
          find(
            ".authorize-api-key__buttons .btn-primary",
            text: I18n.t("user_api_key.authorize"),
          ).click
        else
          click_button(I18n.t("user_api_key.authorize"))
        end
        self
      end

      def has_invalid_code_message?
        has_css?(".form-kit__errors", text: I18n.t("user_api_key.device.invalid_code"))
      end

      def has_completion_message?
        has_css?(".authorize-api-key h1", text: I18n.t("user_api_key.device.complete"), wait: 10) &&
          has_css?(".authorize-api-key p", text: I18n.t("user_api_key.device.return_to_cli"))
      end
    end
  end
end
