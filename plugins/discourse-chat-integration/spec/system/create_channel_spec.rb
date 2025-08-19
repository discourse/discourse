# frozen_string_literal: true
require_relative "../dummy_provider"

RSpec.describe "Create channel", type: :system do
  fab!(:admin)

  include_context "with dummy provider"
  let(:manager) { ::DiscourseChatIntegration::Manager }
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
    visit("/admin/plugins/chat-integration/discord")

    expect(page).to have_no_css(".channel-details")

    click_button(I18n.t("js.chat_integration.create_channel"))

    find("input[name='param-name']").fill_in(with: "bloop")
    find("input[name='param-webhook_url']").fill_in(with: "https://discord.com/api/webhooks/bloop")
    click_button(I18n.t("js.chat_integration.edit_channel_modal.save"))

    expect(page).to have_css(".channel-details")
    expect(find(".channel-info")).to have_content("bloop")
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

    visit("/admin/plugins/chat-integration/dummy")

    expect(find(".error-message")).to have_content(
      I18n.t("js.chat_integration.channels_with_errors"),
    )
    find(".channel-title").find("button").click
    expect(page).to have_content "{\n  \"error_key\": \"hello\"\n}"
  end
end
