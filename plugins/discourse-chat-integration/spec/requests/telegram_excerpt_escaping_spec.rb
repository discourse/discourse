# frozen_string_literal: true

RSpec.describe "Telegram chat integration message escaping", type: :request do
  fab!(:category)
  fab!(:author) { Fabricate(:user, trust_level: 0, refresh_auto_groups: true) }
  fab!(:channel) do
    DiscourseChatIntegration::Channel.create!(
      provider: "telegram",
      data: {
        chat_id: "123",
        name: "Channel",
      },
    )
  end

  let(:posted_messages) { [] }

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_telegram_access_token = "TOKEN"
    SiteSetting.chat_integration_telegram_enabled = true
    SiteSetting.chat_integration_delay_seconds = 0

    DiscourseChatIntegration::Rule.create!(
      channel: channel,
      type: "normal",
      filter: "watch",
      category_id: category.id,
    )

    stub_request(:post, "https://api.telegram.org/botTOKEN/sendMessage").to_return do |request|
      posted_messages << JSON.parse(request.body)
      { status: 200, body: { ok: true }.to_json, headers: { "Content-Type" => "application/json" } }
    end

    sign_in(author)
  end

  def create_post_and_notify(raw)
    post "/posts.json",
         params: {
           title: "Planned maintenance tonight",
           raw: raw,
           category: category.id,
           typing_duration_msecs: 10_000,
         }
    expect(response.status).to eq(200), "post failed: #{response.body}"

    Jobs::NotifyChats.new.execute(post_id: response.parsed_body["id"])
    posted_messages.last
  end

  it "escapes user-typed markup inside the HTML message" do
    message = create_post_and_notify("Maintenance tonight `<!channel>` please save your work")

    expect(message["text"]).to include(
      "<pre>Maintenance tonight &lt;!channel&gt; please save your work</pre>",
    )
  end
end
