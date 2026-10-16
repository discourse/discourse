# frozen_string_literal: true

module PageObjects
  module Pages
    class OmniauthConfirm < PageObjects::Pages::Base
      def visit_provider(provider)
        browser_page.goto("/auth/#{provider}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_logo?
        have_count(0).does_not_match?(
          browser_root.locator(".omniauth-confirm__logo").filter(visible: true),
        )
      end

      def has_card?
        have_count(0).does_not_match?(
          browser_root.locator(".omniauth-confirm__card").filter(visible: true),
        )
      end

      def has_title_for_provider?(provider_name)
        contain_text(
          [browser_text_pattern("Log in with #{provider_name}")],
          useInnerText: true,
        ).matches?(browser_root.locator(".omniauth-confirm__title").filter(visible: true))
      end

      def has_provider_info?(provider_name)
        contain_text([browser_text_pattern(provider_name)], useInnerText: true).matches?(
          browser_root.locator(".omniauth-confirm__provider-name").filter(visible: true),
        )
      end

      def has_site_name_in_footer?(site_name)
        contain_text([browser_text_pattern(site_name)], useInnerText: true).matches?(
          browser_root.locator(".omniauth-confirm__footer").filter(visible: true),
        )
      end

      def has_continue_button?
        have_count(0).does_not_match?(
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{"Continue".to_s.to_json}], [name=#{"Continue".to_s.to_json}]",
              ).or(browser_root.get_by_role("button", name: "Continue")),
            )
            .filter(visible: true),
        )
      end

      def click_continue
        browser_root.locator(".omniauth-confirm__continue-btn").filter(visible: true).click
        self
      end
    end
  end
end
