# frozen_string_literal: true

RSpec.describe "Chat integration notifications", type: :request do
  fab!(:attacker) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:integration_user) { Fabricate(:user, username: "chat-integration") }
  fab!(:category)
  fab!(:visible_tag) { Fabricate(:tag, name: "visible-tag") }
  fab!(:hidden_tag) { Fabricate(:tag, name: "hidden-tag") }
  fab!(:staff_tag_group) do
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
  end
  fab!(:topic) { Fabricate(:topic, category:, tags: [visible_tag, hidden_tag]) }
  fab!(:first_post) { Fabricate(:post, topic:) }
  fab!(:channel) do
    DiscourseChatIntegration::Channel.create!(
      provider: "mattermost",
      data: {
        identifier: "#watched-channel",
      },
    )
  end
  fab!(:rule) do
    DiscourseChatIntegration::Rule.create!(channel:, category_id: category.id, filter: "watch")
  end

  before do
    staff_tag_group
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_discourse_username = integration_user.username
    SiteSetting.chat_integration_mattermost_enabled = true
    SiteSetting.chat_integration_mattermost_webhook_url = "https://mattermost.example/hook"
  end

  it "omits tags hidden from the integration user in a reply notification" do
    webhook =
      stub_request(:post, "https://mattermost.example/hook").to_return(status: 200, body: "ok")

    sign_in(attacker)
    post "/posts.json", params: { raw: "An ordinary reply", topic_id: topic.id }

    expect(response.status).to eq(200)
    created_post_id = response.parsed_body["id"]
    expect(response.body).to include(created_post_id.to_s)

    Jobs::NotifyChats.new.execute(post_id: created_post_id)

    expect(
      a_request(:post, "https://mattermost.example/hook").with do |request|
        title = JSON.parse(request.body).dig("attachments", 0, "title")
        title.include?(visible_tag.name) && !title.include?(hidden_tag.name)
      end,
    ).to have_been_made.once
    expect(webhook).to have_been_requested.once
  end
end
