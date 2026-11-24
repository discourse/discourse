# frozen_string_literal: true

RSpec.describe "Slack chat integration message escaping", type: :request do
  fab!(:category)
  fab!(:author) { Fabricate(:user, trust_level: 0, refresh_auto_groups: true) }
  fab!(:channel) do
    DiscourseChatIntegration::Channel.create!(provider: "slack", data: { identifier: "#general" })
  end

  let(:posted_attachments) { [] }

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_slack_access_token = "xoxb-fake-token"
    SiteSetting.chat_integration_slack_enabled = true
    SiteSetting.chat_integration_delay_seconds = 0

    DiscourseChatIntegration::Rule.create!(
      channel: channel,
      type: "normal",
      filter: "watch",
      category_id: category.id,
    )

    stub_request(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      form = URI.decode_www_form(request.body).to_h
      posted_attachments << JSON.parse(form["attachments"]).first
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

  def create_post_and_notify(raw, title: "Planned maintenance tonight")
    post "/posts.json",
         params: {
           title: title,
           raw: raw,
           category: category.id,
           typing_duration_msecs: 10_000,
         }
    expect(response.status).to eq(200), "post failed: #{response.body}"

    Jobs::NotifyChats.new.execute(post_id: response.parsed_body["id"])
    posted_attachments.last
  end

  it "escapes Slack control sequences typed by an ordinary member" do
    attachment =
      create_post_and_notify(
        "Maintenance starts tonight `<!channel>` please save your work before 22:00",
      )

    expect(attachment["mrkdwn_in"]).to eq(["text"])
    expect(attachment["text"]).to eq(
      "Maintenance starts tonight &lt;!channel&gt; please save your work before 22:00",
    )
  end

  it "escapes a typed Slack user mention" do
    attachment = create_post_and_notify("Ping <@U024BE7LH> about the deploy")

    expect(attachment["text"]).to eq("Ping &lt;@U024BE7LH&gt; about the deploy")
  end

  it "escapes literal angle brackets and ampersands in the excerpt" do
    attachment = create_post_and_notify("AT&T says 1 < 2 and 3 > 2")

    expect(attachment["text"]).to eq("AT&amp;T says 1 &lt; 2 and 3 &gt; 2")
  end

  it "escapes user text inside a link label without breaking the link" do
    attachment = create_post_and_notify("See [the plan>now](https://example.com/plan) for details")

    expect(attachment["text"]).to eq("See <https://example.com/plan|the plan&gt;now> for details")
  end
end
