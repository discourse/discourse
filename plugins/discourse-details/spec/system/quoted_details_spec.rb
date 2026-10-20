# frozen_string_literal: true

describe "Following a quote of text inside details" do
  fab!(:topic)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "reveals the quoted text hidden in details" do
    Fabricate(:post, topic:)
    quoted_post = Fabricate(:post, topic:, raw: "[details=\"Spoiler\"]\nHidden text\n[/details]")
    quoting_post =
      Fabricate(
        :post,
        topic:,
        raw:
          "[quote=\"#{quoted_post.user.username}, post:#{quoted_post.post_number}, topic:#{topic.id}\"]\nHidden text\n[/quote]",
      )

    topic_page.visit_topic(topic, post_number: quoting_post.post_number)
    topic_page.follow_quote(quoting_post)

    expect(topic_page).to have_highlighted_text(quoted_post, "Hidden text", inside: "details[open]")
  end
end
