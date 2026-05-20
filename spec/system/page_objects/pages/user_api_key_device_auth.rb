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

      def has_expiry_notice?(application_name:, expires_at:)
        has_css?(
          ".authorize-api-key__expiry",
          text:
            I18n.t(
              "user_api_key.device.expiry_notice",
              application_name: application_name,
              expires_at: I18n.l(expires_at, format: :long),
            ),
        )
      end

      def enter_code(code)
        code
          .delete("-")
          .chars
          .each_with_index do |character, index|
            find(
              "[aria-label='#{I18n.t("user_api_key.device.code_character", position: index + 1)}']",
            ).fill_in(with: character)
          end

        self
      end

      def click_authorize
        click_button(I18n.t("user_api_key.authorize"))
        self
      end

      def has_completion_message?
        has_css?(".authorize-api-key h1", text: I18n.t("user_api_key.device.complete")) &&
          has_css?(".authorize-api-key p", text: I18n.t("user_api_key.device.return_to_cli"))
      end
    end
  end
end
