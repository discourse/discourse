# frozen_string_literal: true

require 'rails_helper'

describe Admin::PermalinksController do

  it "is a subclass of AdminController" do
    expect(Admin::PermalinksController < Admin::AdminController).to eq(true)
  end

  fab!(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
  end

  describe '#index' do
    it 'filters url' do
      Fabricate(:permalink, url: "/forum/23")
      Fabricate(:permalink, url: "/forum/98")
      Fabricate(:permalink, url: "/discuss/topic/45")
      Fabricate(:permalink, url: "/discuss/topic/76")

      get "/admin/permalinks.json", params: { filter: "topic" }

      expect(response.status).to eq(200)
      result = response.parsed_body
      expect(result.length).to eq(2)
    end

    it 'filters external url' do
      Fabricate(:permalink, external_url: "http://google.com")
      Fabricate(:permalink, external_url: "http://wikipedia.org")
      Fabricate(:permalink, external_url: "http://www.discourse.org")
      Fabricate(:permalink, external_url: "http://try.discourse.org")

      get "/admin/permalinks.json", params: { filter: "discourse" }

      expect(response.status).to eq(200)
      result = response.parsed_body
      expect(result.length).to eq(2)
    end

    it 'filters url and external url both' do
      Fabricate(:permalink, url: "/forum/23", external_url: "http://google.com")
      Fabricate(:permalink, url: "/discourse/98", external_url: "http://wikipedia.org")
      Fabricate(:permalink, url: "/discuss/topic/45", external_url: "http://discourse.org")
      Fabricate(:permalink, url: "/discuss/topic/76", external_url: "http://try.discourse.org")

      get "/admin/permalinks.json", params: { filter: "discourse" }

      expect(response.status).to eq(200)
      result = response.parsed_body
      expect(result.length).to eq(3)
    end
  end

  describe "#create" do
    it "works for topics" do
      topic = Fabricate(:topic)

      post "/admin/permalinks.json", params: {
        url: "/topics/771",
        permalink_type: "topic_id",
        permalink_type_value: topic.id
      }

      expect(response.status).to eq(200)
      expect(Permalink.last).to have_attributes(url: "topics/771", topic_id: topic.id, post_id: nil, category_id: nil, tag_id: nil)
    end

    it "works for posts" do
      some_post = Fabricate(:post)

      post "/admin/permalinks.json", params: {
        url: "/topics/771/8291",
        permalink_type: "post_id",
        permalink_type_value: some_post.id
      }

      expect(response.status).to eq(200)
      expect(Permalink.last).to have_attributes(url: "topics/771/8291", topic_id: nil, post_id: some_post.id, category_id: nil, tag_id: nil)
    end

    it "works for categories" do
      category = Fabricate(:category)

      post "/admin/permalinks.json", params: {
        url: "/forums/11",
        permalink_type: "category_id",
        permalink_type_value: category.id
      }

      expect(response.status).to eq(200)
      expect(Permalink.last).to have_attributes(url: "forums/11", topic_id: nil, post_id: nil, category_id: category.id, tag_id: nil)
    end

    it "works for tags" do
      tag = Fabricate(:tag)

      post "/admin/permalinks.json", params: {
        url: "/forums/12",
        permalink_type: "tag_name",
        permalink_type_value: tag.name
      }

      expect(response.status).to eq(200)
      expect(Permalink.last).to have_attributes(url: "forums/12", topic_id: nil, post_id: nil, category_id: nil, tag_id: tag.id)
    end
  end
end
