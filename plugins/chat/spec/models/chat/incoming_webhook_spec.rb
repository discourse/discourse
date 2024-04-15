# frozen_string_literal: true

RSpec.describe Chat::IncomingWebhook do
  it do
    is_expected.to have_many(:chat_webhook_events)
      .with_foreign_key("incoming_chat_webhook_id")
      .class_name("Chat::WebhookEvent")
      .dependent(:delete_all)
  end

  it { is_expected.to validate_length_of(:name).is_at_most(100) }
  it { is_expected.to validate_length_of(:key).is_at_most(100) }
  it { is_expected.to validate_length_of(:username).is_at_most(100) }
  it { is_expected.to validate_length_of(:description).is_at_most(500) }
  it { is_expected.to validate_length_of(:emoji).is_at_most(100) }
end
