# frozen_string_literal: true

RSpec.describe "Creating posts with nested chat transcripts", type: :request do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:topic)

  before { SiteSetting.chat_enabled = true }

  it "strips transcript mentions without descendant subtree searches during validation" do
    depth = 240
    raw =
      ('<div class="chat-transcript">' + "<i>x</i>" * 12) * depth +
        '<p>hello <span class="mention">@bob</span></p>' + "</div>" * depth
    expect(raw.length).to be < SiteSetting.max_post_length

    sign_in(user)
    selectors = []
    allow_any_instance_of(Nokogiri::HTML5::DocumentFragment).to receive(
      :css,
    ).and_wrap_original do |original, *args|
      selectors << args.first
      original.call(*args)
    end

    post "/posts.json", params: { raw: raw, topic_id: topic.id, typing_duration_msecs: 60_000 }

    expect(response.status).to eq(200)
    expect(response.parsed_body).to have_key("id")
    created_post = Post.find(response.parsed_body["id"])
    fragment = Nokogiri::HTML5.fragment(created_post.cooked)
    expect(fragment.css(".chat-transcript").size).to eq(depth)
    expect(fragment.css(".mention").size).to eq(1)
    expect(created_post.raw_mentions).to eq([])
    expect(selectors).not_to include(".chat-transcript .mention")
  end
end
