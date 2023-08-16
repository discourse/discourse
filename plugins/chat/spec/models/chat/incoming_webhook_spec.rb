# frozen_string_literal: true

RSpec.describe Chat::IncomingWebhook do
  it do
    is_expected.to have_many(:chat_webhook_events)
      .with_foreign_key("incoming_chat_webhook_id")
      .class_name("Chat::WebhookEvent")
      .dependent(:delete_all)
  end
end
