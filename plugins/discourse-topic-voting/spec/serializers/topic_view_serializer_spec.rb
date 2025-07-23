# frozen_string_literal: true

require "rails_helper"

describe TopicViewSerializer do
  let(:user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category_id: category.id) }
  let(:topic_view) { TopicView.new(topic, user) }
  let(:guardian) { Guardian.new(user) }

  describe "can_vote" do
    it "returns nil when voting disabled" do
      SiteSetting.topic_voting_enabled = false
      DiscourseTopicVoting::CategorySetting.create!(category: category)

      json = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

      expect(json[:can_vote]).to eq(nil)
    end

    it "returns false when topic not in category" do
      SiteSetting.topic_voting_enabled = true

      json = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

      expect(json[:can_vote]).to eq(false)
    end

    it "returns false when voting disabled and topic not in category" do
      json = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

      expect(json[:can_vote]).to eq(false)
    end

    it "returns true when voting enabled and topic in category" do
      SiteSetting.topic_voting_enabled = true
      DiscourseTopicVoting::CategorySetting.create!(category: category)

      json = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

      expect(json[:can_vote]).to eq(true)
    end
  end

  describe "vote_count" do
    it "returns the topic vote counts" do
      Fabricate(:topic_voting_vote_count, topic: topic, votes_count: 3)
      json = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

      expect(json[:vote_count]).to eq(3)
    end
  end

  describe "user_voted" do
    it "returns true if the user has voted on the topic" do
      json = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

      expect(json[:user_voted]).to eq(false)

      Fabricate(:topic_voting_votes, topic: topic, user: user)
      json = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

      expect(json[:user_voted]).to eq(false)
    end
  end
end
