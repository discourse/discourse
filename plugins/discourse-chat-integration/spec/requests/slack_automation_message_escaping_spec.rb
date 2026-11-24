# frozen_string_literal: true

RSpec.describe "Slack automation message escaping", type: :request do
  fab!(:category)
  fab!(:tag)
  fab!(:author) { Fabricate(:user, trust_level: 0, refresh_auto_groups: true) }

  let(:posted_attachments) { [] }
  let(:title) { "Maintenance <!channel> tonight at 22:00" }

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_slack_access_token = "xoxb-fake-token"
    SiteSetting.chat_integration_slack_enabled = true
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.tagging_enabled = true

    automation =
      Fabricate(
        :automation,
        script: "send_slack_message",
        trigger: "topic_tags_changed",
        enabled: true,
      )
    automation.upsert_field!("watching_tags", "tags", { "value" => [tag.name] }, target: "trigger")
    automation.upsert_field!(
      "message",
      "message",
      { "value" => "Tagged: ${TOPIC}" },
      target: "script",
    )
    automation.upsert_field!("url", "text", { "value" => "https://example.com" }, target: "script")
    automation.upsert_field!("channel", "text", { "value" => "general" }, target: "script")

    stub_request(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted_attachments << JSON.parse(URI.decode_www_form(request.body).to_h["attachments"]).first
      {
        status: 200,
        body: { ok: true, ts: "1700000000.000001" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      }
    end

    sign_in(author)
  end

  it "escapes the topic title substituted into the mrkdwn message" do
    post "/posts.json",
         params: {
           title: title,
           raw: "Scheduled maintenance, please save your work.",
           category: category.id,
           typing_duration_msecs: 10_000,
         }

    expect(response.status).to eq(200), "post failed: #{response.body}"

    put "/t/#{response.parsed_body["topic_id"]}.json", params: { tags: [{ id: tag.id }] }

    expect(response.status).to eq(200), "tagging failed: #{response.body}"

    attachment = posted_attachments.last
    expect(attachment).to be_present
    expect(attachment["mrkdwn_in"]).to eq(["text"])
    expect(attachment["text"]).to eq("Tagged: Maintenance &lt;!channel&gt; tonight at 22:00")
    expect(attachment["fallback"]).to eq("Tagged: Maintenance <!channel> tonight at 22:00")
    expect(attachment["title"]).to eq("#{title} [#{category.name}] #{tag.name}")
  end
end
