# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe "topics/show.html.erb" do
  fab!(:topic) { Fabricate(:topic) }

  it "add nofollow to RSS alternate link for topic" do
    topic_view = OpenStruct.new(
      topic: topic,
      posts: []
    )
    topic_view.stubs(:summary).returns('')
    view.stubs(:crawler_layout?).returns(false)
    view.stubs(:url_for).returns('https://www.example.com/test.rss')
    view.instance_variable_set("@topic_view", topic_view)
    render template: 'topics/show', formats: [:html]

    expect(view.content_for(:head)).to match(/<link rel="alternate nofollow" type="application\/rss\+xml" title="[^"]+" href="https:\/\/www.example.com\/test\.rss" \/>/)
  end

end
