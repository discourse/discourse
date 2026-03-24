# frozen_string_literal: true
require_relative "../dummy_provider"

RSpec.describe "Create channel" do
  fab!(:admin)

  include_context "with dummy provider"
  let(:manager) { DiscourseChatIntegration::Manager }
  let(:chan1) { DiscourseChatIntegration::Channel.create!(provider: "dummy") }
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category_id: category.id) }
  let(:first_post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_discord_enabled = true
    sign_in(admin)
  end

  it "creates and displays a new channel" do
    visit("/admin/plugins/discourse-chat-integration/providers/discord")

    expect(page).to have_no_css(".channel-details")

    find("#create-channel").click if page.has_css?("#create-channel", wait: 0)

    expect(page).to have_css(".inline-channel-form")

    find(".form-kit__field[data-name='name'] input").fill_in(with: "bloop")
    find(".form-kit__field[data-name='webhook_url'] input").fill_in(
      with: "https://discord.com/api/webhooks/bloop",
    )
    find(".inline-channel-form .btn-primary").click

    expect(page).to have_css(".channel-details")
    expect(find(".channel-details")).to have_content("bloop")
  end

  it "shows the error in the channel modal" do
    DiscourseChatIntegration::Rule.create!(
      channel: chan1,
      filter: "watch",
      category_id: category.id,
    )

    provider.set_raise_exception(
      DiscourseChatIntegration::ProviderError.new info: { error_key: "hello" }
    )
    manager.trigger_notifications(first_post.id)

    visit("/admin/plugins/discourse-chat-integration/providers/dummy")

    expect(find(".chat-integration-error-banner")).to have_content(
      I18n.t("js.chat_integration.channels_with_errors"),
    )
    find(".channel-title").find("button").click
    expect(page).to have_content "{\n  \"error_key\": \"hello\"\n}"
  end
end
