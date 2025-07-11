# frozen_string_literal: true

require "rails_helper"

describe ListController do
  fab!(:user)
  fab!(:topic)
  # "topics/voted-by/:username"
  before { SiteSetting.topic_voting_enabled = true }

  it "allow anons to view votes" do
    DiscourseTopicVoting::Vote.create!(user: user, topic: topic)

    get "/topics/voted-by/#{user.username}.json"
    topic_json = response.parsed_body.dig("topic_list", "topics").first

    expect(topic_json["id"]).to eq(topic.id)
  end

  it "returns a 404 when we don't show votes on profiles" do
    DiscourseTopicVoting::Vote.create!(user: user, topic: topic)
    SiteSetting.topic_voting_show_votes_on_profile = false

    get "/topics/voted-by/#{user.username}.json"

    expect(response.status).to eq(404)
  end

  context "in a category" do
    fab!(:category1) { Fabricate(:category) }
    fab!(:category2) { Fabricate(:category) }
    fab!(:topic1) do
      Fabricate(:topic, category: category1, title: "Topic in votes-enabled category 1")
    end
    fab!(:topic2) do
      Fabricate(:topic, category: category2, title: "Topic in votes-enabled category 2")
    end

    before do
      DiscourseTopicVoting::CategorySetting.create!(category: category1)
      DiscourseTopicVoting::CategorySetting.create!(category: category2)
    end

    it "allows anons to view votes RSS feed" do
      DiscourseTopicVoting::Vote.create!(user: user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: user, topic: topic2)

      get "/c/#{category2.slug}/#{category2.id}/l/votes.rss"

      expect(response.status).to eq(200)
      expect(response.body).to include(topic2.title)
      # ensure we don't include votes from other categories
      expect(response.body).not_to include(topic1.title)
    end
  end
end
