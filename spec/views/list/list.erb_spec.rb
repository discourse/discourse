# frozen_string_literal: true

require "rails_helper"

RSpec.describe "list/list.erb" do
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic) }

  it "add nofollow to RSS alternate link for category" do
    view.stubs(:include_crawler_content?).returns(false)
    view.stubs(:url_for).returns("https://www.example.com/test.rss")
    view.instance_variable_set("@rss", false)
    view.instance_variable_set("@category", category)
    render template: "list/list", formats: []

    expect(view.content_for(:head)).to match(
      %r{<link rel="alternate nofollow" type="application/rss\+xml" title="[^"]+" href="https://www.example.com/test\.rss" />},
    )
  end

  it "adds structured data" do
    view.stubs(:include_crawler_content?).returns(true)
    topic.posters = []
    assign(:list, OpenStruct.new(topics: [topic]))

    render template: "list/list", formats: []

    topic_list = Nokogiri::HTML5.fragment(rendered).css(".topic-list")
    first_item = topic_list.css('[itemprop="itemListElement"]')
    expect(first_item.css('[itemprop="position"]')[0]["content"]).to eq("1")
    expect(first_item.css('[itemprop="url"]')[0]["href"]).to eq(topic.url)
  end
end
