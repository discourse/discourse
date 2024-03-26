# frozen_string_literal: true

require "ostruct"

RSpec.describe "topics/show.html.erb" do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }

  it "uses subfolder-safe category url" do
    set_subfolder "/subpath"
    topic_view = OpenStruct.new(topic: topic, posts: [], crawler_posts: [])
    topic_view.stubs(:summary).returns("")
    view.stubs(:crawler_layout?).returns(false)
    assign(:topic_view, topic_view)
    assign(:breadcrumbs, [{ name: category.name, color: category.color }])
    assign(:tags, [])

    render template: "topics/show", formats: [:html]

    assert_select "a[href='/subpath/c/#{category.slug}/#{category.id}']"
  end

  it "add nofollow to RSS alternate link for topic" do
    topic_view = OpenStruct.new(topic: topic, posts: [], crawler_posts: [])
    topic_view.stubs(:summary).returns("")
    view.stubs(:crawler_layout?).returns(false)
    view.stubs(:url_for).returns("https://www.example.com/test.rss")
    view.instance_variable_set("@topic_view", topic_view)
    assign(:tags, [])

    render template: "topics/show", formats: [:html]

    expect(view.content_for(:head)).to match(
      %r{<link rel="alternate nofollow" type="application/rss\+xml" title="[^"]+" href="https://www.example.com/test\.rss" />},
    )
  end

  it "adds structured data" do
    view.stubs(:include_crawler_content?).returns(true)
    post = Fabricate(:post, topic: topic)
    TopicLink.create!(
      topic_id: post.topic_id,
      post_id: post.id,
      user_id: post.user_id,
      url: "https://example.com/",
      domain: "example.com",
      link_topic_id: Fabricate(:topic).id,
      reflection: true,
    )
    assign(:topic_view, TopicView.new(topic))
    assign(:tags, [])

    render template: "topics/show", formats: [:html]

    links_list = Nokogiri::HTML5.fragment(rendered).css(".crawler-linkback-list")
    first_item = links_list.css('[itemprop="itemListElement"]')
    expect(first_item.css('[itemprop="position"]')[0]["content"]).to eq("1")
    expect(first_item.css('[itemprop="url"]')[0]["href"]).to eq("https://example.com/")
  end

  it "uses comment scheme type for replies" do
    view.stubs(:crawler_layout?).returns(true)
    view.stubs(:include_crawler_content?).returns(true)
    Fabricate(:post, topic: topic)
    Fabricate(:post, topic: topic)
    Fabricate(:post, topic: topic)
    assign(:topic_view, TopicView.new(topic))
    assign(:tags, [])

    render template: "topics/show", formats: [:html]

    doc = Nokogiri::HTML5.fragment(rendered)
    topic_schema = doc.css('[itemtype="http://schema.org/DiscussionForumPosting"]')
    expect(topic_schema.size).to eq(1)
    expect(topic_schema.css('[itemtype="http://schema.org/Comment"]').size).to eq(2)
    expect(topic_schema.css('[itemprop="articleSection"]')[0]["content"]).to eq(topic.category.name)
  end
end
