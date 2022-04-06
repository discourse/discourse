# frozen_string_literal: true

require "rails_helper"

describe "list/list.erb" do
  fab!(:category) { Fabricate(:category) }

  it "add nofollow to RSS alternate link for category" do
    view.stubs(:include_crawler_content?).returns(false)
    view.stubs(:url_for).returns('https://www.example.com/test.rss')
    view.instance_variable_set("@rss", false)
    view.instance_variable_set("@category", category)
    render template: 'list/list', formats: []

    expect(view.content_for(:head)).to match(/<link rel="alternate nofollow" type="application\/rss\+xml" title="[^"]+" href="https:\/\/www.example.com\/test\.rss" \/>/)
  end

end
