# frozen_string_literal: true

module PageObjects
  module Pages
    class UserApiKeyShow < PageObjects::Pages::Base
      def visit_authorization(public_key:)
        page.visit(
          "/user-api-key/new?#{
            URI.encode_www_form(
              scopes: "read",
              client_id: "x" * 32,
              application_name: "Test Application",
              public_key: public_key,
              nonce: SecureRandom.hex,
            )
          }",
        )

        self
      end

      def visit_otp(public_key:)
        page.visit(
          "/user-api-key/otp?#{
            URI.encode_www_form(
              application_name: "Test Application",
              public_key: public_key,
              auth_redirect: "discourse://auth_redirect",
            )
          }",
        )

        self
      end

      def click_authorize
        click_button(I18n.t("user_api_key.authorize"))
        self
      end

      def click_copy_key
        find("#copy-api-key-btn").click
        self
      end

      def payload
        find("#user-api-key-payload").text
      end

      def has_authorization_form?
        has_css?(".authorize-api-key h1", text: "Test Application") &&
          has_button?(I18n.t("user_api_key.authorize"))
      end

      def has_payload?
        has_css?("#user-api-key-payload") && has_css?("#copy-api-key-btn")
      end

      def has_copied_button?
        has_button?(I18n.t("user_api_key.copied"))
      end

      def has_otp_form?
        has_css?(
          ".authorize-api-key h1",
          text: I18n.t("user_api_key.otp_description", application_name: "Test Application"),
        ) && has_button?(I18n.t("user_api_key.authorize"))
      end

      def has_no_sidebar?
        has_no_css?("#d-sidebar")
      end

      def has_no_powered_by_discourse?
        has_no_css?(".powered-by-discourse")
      end
    end
  end
end
