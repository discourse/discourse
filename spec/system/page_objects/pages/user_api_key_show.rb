# frozen_string_literal: true

module PageObjects
  module Pages
    class UserApiKeyShow < PageObjects::Pages::Base
      def visit_authorization(public_key:)
        browser_page
          .goto(
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
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        self
      end

      def visit_otp(public_key:)
        browser_page
          .goto(
            "/user-api-key/otp?#{
              URI.encode_www_form(
                application_name: "Test Application",
                public_key: public_key,
                auth_redirect: "discourse://auth_redirect",
              )
            }",
          )
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        self
      end

      def click_authorize
        browser_root
          .locator(
            "[id=#{I18n.t("user_api_key.authorize").to_s.to_json}], [name=#{I18n.t("user_api_key.authorize").to_s.to_json}]",
          )
          .or(browser_root.get_by_role("button", name: I18n.t("user_api_key.authorize")))
          .filter(visible: true)
          .click
        self
      end

      def click_copy_key
        browser_root.locator("#copy-api-key-btn").filter(visible: true).click
        self
      end

      def payload
        browser_root.locator("#user-api-key-payload").filter(visible: true).inner_text.strip
      end

      def has_authorization_form?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern("Test Application")],
          useInnerText: true,
        ).matches?(browser_root.locator(".authorize-api-key h1").filter(visible: true)) &&
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root
              .get_by_role("button")
              .and(
                browser_root.locator(
                  "[id=#{I18n.t("user_api_key.authorize").to_s.to_json}], [name=#{I18n.t("user_api_key.authorize").to_s.to_json}]",
                ).or(browser_root.get_by_role("button", name: I18n.t("user_api_key.authorize"))),
              )
              .filter(visible: true),
          )
      end

      def has_payload?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#user-api-key-payload").filter(visible: true),
        ) &&
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("#copy-api-key-btn").filter(visible: true),
          )
      end

      def has_copied_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{I18n.t("user_api_key.copied").to_s.to_json}], [name=#{I18n.t("user_api_key.copied").to_s.to_json}]",
              ).or(browser_root.get_by_role("button", name: I18n.t("user_api_key.copied"))),
            )
            .filter(visible: true),
        )
      end

      def has_otp_form?
        PlaywrightMatchers.contain_text(
          [
            browser_text_pattern(
              I18n.t("user_api_key.otp_description", application_name: "Test Application"),
            ),
          ],
          useInnerText: true,
        ).matches?(browser_root.locator(".authorize-api-key h1").filter(visible: true)) &&
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root
              .get_by_role("button")
              .and(
                browser_root.locator(
                  "[id=#{I18n.t("user_api_key.authorize").to_s.to_json}], [name=#{I18n.t("user_api_key.authorize").to_s.to_json}]",
                ).or(browser_root.get_by_role("button", name: I18n.t("user_api_key.authorize"))),
              )
              .filter(visible: true),
          )
      end

      def has_no_sidebar?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#d-sidebar").filter(visible: true),
        )
      end

      def has_no_powered_by_discourse?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".powered-by-discourse").filter(visible: true),
        )
      end
    end
  end
end
