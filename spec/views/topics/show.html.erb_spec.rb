# frozen_string_literal: true

RSpec.describe "topics/show.html.erb" do
  fab!(:topic) { Fabricate(:topic, category: Fabricate(:category)) }

  it "adds nofollow to RSS alternate link" do
    topic_view = OpenStruct.new(topic: topic, posts: [], crawler_posts: [])
    topic_view.stubs(:summary).returns("")
    view.stubs(:crawler_layout?).returns(false)
    view.stubs(:url_for).returns("https://example.com/test.rss")
    view.instance_variable_set("@topic_view", topic_view)
    assign(:tags, [])

    render template: "topics/show", formats: [:html]

    expect(view.content_for(:head)).to match(
      %r{<link rel="alternate nofollow" type="application/rss\+xml"},
    )
  end

  it "renders linkbacks as plain links without ItemList schema" do
    view.stubs(:include_crawler_content?).returns(true)
    post = Fabricate(:post, topic: topic)
    TopicLink.create!(
      topic_id: post.topic_id,
      post_id: post.id,
      user_id: post.user_id,
      url: "https://example.com/linked",
      domain: "example.com",
      link_topic_id: Fabricate(:topic).id,
      reflection: true,
    )
    assign(:topic_view, TopicView.new(topic))
    assign(:tags, [])

    render template: "topics/show", formats: [:html]

    doc = Nokogiri::HTML5.fragment(rendered)
    linkbacks = doc.css(".crawler-linkback-list")
    expect(linkbacks.css("a[href='https://example.com/linked']")).to be_present
    expect(linkbacks.css('[itemtype*="ItemList"]')).to be_empty
  end

  it "uses DiscussionForumPosting with Comment schema for replies" do
    view.stubs(:crawler_layout?).returns(true)
    view.stubs(:include_crawler_content?).returns(true)
    3.times { Fabricate(:post, topic: topic) }
    assign(:topic_view, TopicView.new(topic))
    assign(:tags, [])

    render template: "topics/show", formats: [:html]

    doc = Nokogiri::HTML5.fragment(rendered)
    posting = doc.css('[itemtype*="DiscussionForumPosting"]')
    expect(posting.size).to eq(1)
    expect(posting.css('[itemtype*="Comment"]').size).to eq(2) # replies only, not OP
    expect(posting.css('[itemprop="articleSection"]').first["content"]).to eq(topic.category.name)
  end
end
