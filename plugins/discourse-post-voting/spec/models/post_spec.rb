# frozen_string_literal: true

require "rails_helper"

describe Post do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:up) { PostVotingVote.directions[:up] }
  let(:users) { [user1, user2, user3] }

  before { SiteSetting.post_voting_enabled = true }

  describe "validation" do
    it "ensures that post cannot be created with reply_to_post_number set" do
      post.reply_to_post_number = 3

      expect(post.valid?).to eq(false)

      expect(post.errors.full_messages).to contain_exactly(
        I18n.t("post.post_voting.errors.replying_to_post_not_permited"),
      )
    end
  end

  it("should ignore vote_count") { expect(Post.ignored_columns.include?("vote_count")).to eq(true) }

  it "should return last voted correctly" do
    freeze_time do
      expect(post.post_voting_last_voted(user1.id)).to eq(nil)

      PostVoting::VoteManager.vote(post, user1)

      expect(post.post_voting_last_voted(user1.id)).to eq_time(Time.zone.now)
    end
  end

  it "should return post_voting_can_vote correctly" do
    expect(post.post_voting_can_vote(user1.id, PostVotingVote.directions[:up])).to eq(true)

    PostVoting::VoteManager.vote(post, user1)

    expect(post.post_voting_can_vote(user1.id, PostVotingVote.directions[:up])).to eq(false)
  end
end
