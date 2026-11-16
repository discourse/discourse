# frozen_string_literal: true

describe "Following a quote containing a local date" do
  fab!(:topic)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "shows the whole quoted text including the date" do
    text = "Party on [date=2030-11-20 time=18:00:00 timezone=\"Europe/Paris\"] at the harbour"
    quoted_post = Fabricate(:post, topic:, raw: text)
    quoting_post =
      Fabricate(
        :post,
        topic:,
        raw:
          "[quote=\"#{quoted_post.user.username}, post:1, topic:#{topic.id}\"]\n#{text}\n[/quote]",
      )

    topic_page.visit_topic(topic, post_number: quoting_post.post_number)
    topic_page.follow_quote(quoting_post)

    expect(topic_page).to have_highlighted_text(quoted_post, "harbour")
  end
end
