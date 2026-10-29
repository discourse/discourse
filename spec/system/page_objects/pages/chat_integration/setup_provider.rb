# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatIntegrationSetupProvider < PageObjects::Pages::Base
      FORM_SCOPE = "#chat-integration-setup-provider-modal"

      def form
        @form ||= PageObjects::Components::FormKit.new(FORM_SCOPE)
      end

      def setup_provider(provider_name)
        find(".chat-integration-provider-new__item.--#{provider_name}").find(
          ".chat-integration-provider-new__setup",
        ).click
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
        within(FORM_SCOPE) { has_css?(".form-kit__field[data-name='#{field_name}'].has-error") }
      end
    end
  end
end
