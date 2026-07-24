# frozen_string_literal: true

RSpec.describe PostVoting::GuardianExtension do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE, user: other_user) }
  fab!(:post) { Fabricate(:post, topic:, user: other_user) }

  before { SiteSetting.post_voting_enabled = true }

  describe "#can_vote_on_post?" do
    it "returns true for a valid post-voting post" do
      expect(Guardian.new(user).can_vote_on_post?(post)).to eq(true)
    end

    it "returns false for anonymous users" do
      expect(Guardian.new(nil).can_vote_on_post?(post)).to eq(false)
    end

    it "returns false when the post is missing" do
      expect(Guardian.new(user).can_vote_on_post?(nil)).to eq(false)
    end

    it "returns false when the topic is not a post-voting topic" do
      regular_topic = Fabricate(:topic, user: other_user)
      regular_post = Fabricate(:post, topic: regular_topic, user: other_user)
      expect(Guardian.new(user).can_vote_on_post?(regular_post)).to eq(false)
    end

    it "returns false when the user owns the post" do
      own_post = Fabricate(:post, topic:, user: user)
      expect(Guardian.new(user).can_vote_on_post?(own_post)).to eq(false)
    end

    it "returns false when the topic is archived" do
      topic.update!(archived: true)
      expect(Guardian.new(user).can_vote_on_post?(post)).to eq(false)
    end

    it "returns false when the topic is closed" do
      topic.update!(closed: true)
      expect(Guardian.new(user).can_vote_on_post?(post)).to eq(false)
    end

    context "with a direction" do
      it "returns false when the user has already voted in that direction" do
        Fabricate(:post_voting_vote, votable: post, user: user, direction: "up")
        expect(Guardian.new(user).can_vote_on_post?(post, direction: "up")).to eq(false)
      end

      it "allows voting in the opposite direction within the undo window" do
        Fabricate(:post_voting_vote, votable: post, user: user, direction: "up")
        expect(Guardian.new(user).can_vote_on_post?(post, direction: "down")).to eq(true)
      end

      it "blocks direction switching after the undo window closes" do
        SiteSetting.post_voting_undo_vote_action_window = 5
        Fabricate(
          :post_voting_vote,
          votable: post,
          user: user,
          direction: "up",
          created_at: 10.minutes.ago,
        )
        expect(Guardian.new(user).can_vote_on_post?(post, direction: "down")).to eq(false)
      end
    end
  end
end
