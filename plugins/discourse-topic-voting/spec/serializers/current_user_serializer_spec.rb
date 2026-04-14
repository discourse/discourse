# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:user1) { Fabricate(:user, trust_level: 3) }
  let(:user2) { Fabricate(:user) }
  fab!(:guardian) { Guardian.new(user1) }
  fab!(:category)
  fab!(:topic1) { Fabricate(:topic, category_id: category.id) }
  let(:topic2) { Fabricate(:topic, category_id: category.id) }
  let(:topic3) { Fabricate(:topic, category_id: category.id) }
  let(:topic4) { Fabricate(:topic, category_id: category.id) }

  it "does not return attributes related to voting if disabled" do
    SiteSetting.topic_voting_enabled = false
    json = described_class.new(user1, scope: guardian, root: false).as_json

    expect(json[:votes_exceeded]).to eq(nil)
    expect(json[:vote_count]).to eq(nil)
    expect(json[:votes_left]).to eq(nil)
  end

  it "returns nil for vote_limit and votes_left when vote limits are disabled" do
    SiteSetting.topic_voting_enabled = true
    SiteSetting.topic_voting_enable_vote_limits = false
    Fabricate(:topic_voting_votes, user: user1, topic: topic1)

    json = described_class.new(user1, scope: guardian, root: false).as_json

    expect(json[:vote_limit]).to be_nil
    expect(json[:votes_left]).to be_nil
    expect(json[:votes_exceeded]).to eq(false)
  end

  describe "votes_exceeded" do
    it "returns false when within voting limits" do
      SiteSetting.topic_voting_enabled = true
      SiteSetting.topic_voting_tl3_vote_limit = 1
      Fabricate(:topic_voting_votes, user: user2, topic: topic1)

      json = described_class.new(user1, scope: guardian, root: false).as_json

      expect(json[:votes_exceeded]).to eq(false)
    end

    it "returns true when hit voting limits" do
      SiteSetting.topic_voting_enabled = true
      SiteSetting.topic_voting_tl3_vote_limit = 1
      Fabricate(:topic_voting_votes, user: user1, topic: topic1)

      json = described_class.new(user1, scope: guardian, root: false).as_json

      expect(json[:votes_exceeded]).to eq(true)
    end
  end

  describe "votes_left" do
    it "returns the number of votes the user has left" do
      SiteSetting.topic_voting_tl3_vote_limit = 3

      json = described_class.new(user1, scope: guardian, root: false).as_json

      expect(json[:votes_left]).to eq(3)

      Fabricate(:topic_voting_votes, user: user1, topic: topic1)
      Fabricate(:topic_voting_votes, user: user1, topic: topic2)
      Fabricate(:topic_voting_votes, user: user1, topic: topic3)
      json = described_class.new(user1, scope: guardian, root: false).as_json

      expect(json[:votes_left]).to eq(0)

      Fabricate(:topic_voting_votes, user: user1, topic: topic4)
      json = described_class.new(user1, scope: guardian, root: false).as_json

      expect(json[:votes_left]).to eq(0)
    end
  end
end
