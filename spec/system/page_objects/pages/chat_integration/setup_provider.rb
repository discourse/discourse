# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatIntegrationSetupProvider < PageObjects::Pages::Base
      FORM_SCOPE = "#chat-integration-setup-provider-modal"

      def form
        @form ||= PageObjects::Components::FormKit.new(FORM_SCOPE)
      end

      def add_provider_menu
        PageObjects::Components::DMenu.new(
          browser_root.locator(".chat-integration-add-provider-trigger").filter(visible: true),
        )
      end

      def setup_popular_provider(provider_name)
        browser_root
          .locator(".chat-integration-providers-list")
          .filter(visible: true)
          .locator(".chat-integration-popular-provider-setup.--#{provider_name}")
          .filter(visible: true)
          .click
        self
      end

      def fill_slack_access_token(value)
        form.field("chat_integration_slack_access_token").fill_in(value)
        self
      end

      def fill_slack_webhook_url(value)
        form.field("chat_integration_slack_outbound_webhook_url").fill_in(value)
        self
      end

      def fill_telegram_access_token(value)
        form.field("chat_integration_telegram_access_token").fill_in(value)
        self
      end

      def submit
        form.submit
        self
      end

      def has_field_error?(field_name)
        within_browser(FORM_SCOPE) do
          have_count(0).does_not_match?(
            browser_root.locator(".form-kit__field[data-name='#{field_name}'].has-error").filter(
              visible: true,
            ),
          )
        end
      end
    end
  end
end
