# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminIncomingWebhooks < PageObjects::Pages::Base
      def visit
        page.visit("/admin/plugins/chat/hooks")
        self
      end

      def click_new
        find(".admin-incoming-webhooks-new").click
      end

      def channel_chooser
        PageObjects::Components::SelectKit.new(".chat-channel-chooser")
      end

      def form
        PageObjects::Components::FormKit.new(".discourse-chat-incoming-webhooks .form-kit")
      end

      def list_row(webhook_id)
        find(".incoming-chat-webhooks-row[data-webhook-id='#{webhook_id}']")
      end
    end
  end
end
