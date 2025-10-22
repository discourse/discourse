# frozen_string_literal: true

describe PostVotingCommentSerializer do
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user)
  fab!(:comment) { Fabricate(:post_voting_comment, post: post) }

  before do
    SiteSetting.post_voting_enabled = true
    PostVoting::VoteManager.vote(comment, post.user)
  end

  context "with a comment user" do
    it "returns the right attributes for an anonymous user" do
      serializer = described_class.new(comment, scope: Guardian.new)
      serialized_comment = serializer.as_json[:post_voting_comment]

      expect(serialized_comment[:id]).to eq(comment.id)
      expect(serialized_comment[:created_at]).to eq_time(comment.created_at)
      expect(serialized_comment[:post_voting_vote_count]).to eq(1)
      expect(serialized_comment[:cooked]).to eq(comment.cooked)
      expect(serialized_comment[:name]).to eq(comment.user.name)
      expect(serialized_comment[:username]).to eq(comment.user.username)
    end

    it "returns the right attributes for logged in user" do
      serializer = described_class.new(comment, scope: Guardian.new(post.user))
      serialized_comment = serializer.as_json[:post_voting_comment]

      expect(serialized_comment[:id]).to eq(comment.id)
      expect(serialized_comment[:created_at]).to eq_time(comment.created_at)
      expect(serialized_comment[:post_voting_vote_count]).to eq(1)
      expect(serialized_comment[:cooked]).to eq(comment.cooked)
      expect(serialized_comment[:name]).to eq(comment.user.name)
      expect(serialized_comment[:username]).to eq(comment.user.username)
      expect(serialized_comment[:user_voted]).to eq(true)
    end
  end

  context "with a deleted comment user" do
    before do
      comment.user.destroy
      comment.reload
    end

    it "does not fail to serialize" do
      serializer = described_class.new(comment, scope: Guardian.new(post.user))
      serialized_comment = serializer.as_json[:post_voting_comment]

      expect(serialized_comment[:id]).to eq(comment.id)
      expect(serialized_comment[:name]).to be_nil
      expect(serialized_comment[:username]).to be_nil
    end
  end
end
