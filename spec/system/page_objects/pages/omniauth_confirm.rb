# frozen_string_literal: true

module PageObjects
  module Pages
    class OmniauthConfirm < PageObjects::Pages::Base
      def visit_provider(provider)
        visit("/auth/#{provider}")
        self
      end

      def has_logo?
        has_css?(".omniauth-confirm__logo")
      end

      def has_card?
        has_css?(".omniauth-confirm__card")
      end

      def has_title_for_provider?(provider_name)
        has_css?(".omniauth-confirm__title", text: "Log in with #{provider_name}")
      end

      def has_provider_info?(provider_name)
        has_css?(".omniauth-confirm__provider-name", text: provider_name)
      end

      def has_site_name_in_footer?(site_name)
        has_css?(".omniauth-confirm__footer", text: site_name)
      end

      def has_continue_button?
        has_button?("Continue")
      end

      def click_continue
        find(".omniauth-confirm__continue-btn").click
        self
      end
    end
  end
end
