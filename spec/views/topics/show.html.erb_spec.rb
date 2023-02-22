# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe "topics/show.html.erb" do
  fab!(:topic) { Fabricate(:topic) }

  it "add nofollow to RSS alternate link for topic" do
    topic_view = OpenStruct.new(topic: topic, posts: [])
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

  it "adds sturctured data" do
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
end
