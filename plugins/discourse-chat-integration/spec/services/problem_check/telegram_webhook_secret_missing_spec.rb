# frozen_string_literal: true

RSpec.describe ProblemCheck::TelegramWebhookSecretMissing do
  let(:check) { described_class.new }

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_telegram_enabled = true
  end

  it "warns when Telegram slash commands have no webhook secret" do
    SiteSetting.chat_integration_telegram_secret = ""

    expect(check).to have_a_problem.with_priority("low").with_message(
      "Telegram slash commands stopped working because the Telegram access token changed or chat integration was disabled. Disable the Telegram provider and set it up again in <a href='/admin/plugins/discourse-chat-integration'>the chat integration section</a>.",
    )
  end

  it "is chill when the webhook secret is set" do
    SiteSetting.chat_integration_telegram_secret = "shhh"

    expect(check).to be_chill_about_it
  end
end
