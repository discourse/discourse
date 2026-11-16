# frozen_string_literal: true

describe "Quoted text highlighting" do
  fab!(:user)
  fab!(:topic)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "shows the quoted text when expanding or following a quote" do
    quoted_markdown = "Hello **bold** and [a link](https://example.com)\n\nSecond `code` paragraph"
    filler = 40.times.map { |i| "Filler paragraph #{i}." }.join("\n\n")
    quoted_post = Fabricate(:post, topic:, raw: "#{filler}\n\n#{quoted_markdown}")
    Fabricate.times(30, :post, topic:, user:)
    quoting_post =
      Fabricate(
        :post,
        topic:,
        raw:
          "[quote=\"#{quoted_post.user.username}, post:1, topic:#{topic.id}\"]\n#{quoted_markdown}\n[/quote]",
      )

    topic_page.visit_topic(topic, post_number: quoting_post.post_number)

    topic_page.expand_quote(quoting_post)
    expect(topic_page).to have_highlighted_text(
      quoting_post,
      "Hello bold and a link Second code paragraph",
    )

    topic_page.follow_quote(quoting_post)
    expect(topic_page).to have_highlighted_text(
      quoted_post,
      "Hello bold and a link Second code paragraph",
    )
  end

  it "shows the quoted text inside a nested quote when expanding" do
    source = Fabricate(:post, topic:, raw: "Original words from the source")
    quoted_post =
      Fabricate(
        :post,
        topic:,
        raw:
          "[quote=\"#{source.user.username}, post:1, topic:#{topic.id}\"]\nOriginal words from the source\n[/quote]\nA reply",
      )
    quoting_post =
      Fabricate(
        :post,
        topic:,
        raw:
          "[quote=\"#{quoted_post.user.username}, post:#{quoted_post.post_number}, topic:#{topic.id}\"]\nOriginal words from the source\n[/quote]",
      )

    topic_page.visit_topic(topic, post_number: quoting_post.post_number)
    topic_page.expand_quote(quoting_post)

    expect(topic_page).to have_highlighted_text(quoting_post, "Original words from the source")
  end
end
