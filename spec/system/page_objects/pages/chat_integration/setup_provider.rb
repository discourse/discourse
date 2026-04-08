# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatIntegrationSetupProvider < PageObjects::Pages::Base
      def setup_modal
        find("#chat-integration-setup-provider-modal")
      end

      def fill_slack_access_token(value)
        setup_modal.find(
          ".form-kit__field[data-name='chat_integration_slack_access_token'] input",
        ).fill_in(with: value)
      end

      def fill_slack_webhook_url(value)
        setup_modal.find(
          ".form-kit__field[data-name='chat_integration_slack_outbound_webhook_url'] input",
        ).fill_in(with: value)
      end

      def fill_telegram_access_token(value)
        setup_modal.find(
          ".form-kit__field[data-name='chat_integration_telegram_access_token'] input",
        ).fill_in(with: value)
      end

      def submit
        setup_modal.find("#save-rule").click
      end

      def has_field_error?(field_name)
        setup_modal.has_css?(".form-kit__field[data-name='#{field_name}'].has-error")
      end
    end
  end
end
