# frozen_string_literal: true

RSpec.describe PostMover do
  fab!(:admin)
  fab!(:user1, :user)
  fab!(:user2, :user)

  before do
    SiteSetting.post_voting_enabled = true
    Jobs.run_immediately!
  end

  describe "moving posts with post voting data" do
    fab!(:original_topic) { Fabricate(:topic, user: admin, subtype: Topic::POST_VOTING_SUBTYPE) }
    fab!(:destination_topic) { Fabricate(:topic, user: admin) }

    fab!(:op) { Fabricate(:post, topic: original_topic, user: admin) }
    fab!(:reply) { Fabricate(:post, topic: original_topic, user: admin) }

    fab!(:op_comment) { Fabricate(:post_voting_comment, post: op, user: user1) }
    fab!(:op_vote) { Fabricate(:post_voting_vote, votable: op, user: user1, direction: "up") }

    fab!(:reply_comment) { Fabricate(:post_voting_comment, post: reply, user: user2) }
    fab!(:reply_vote) { Fabricate(:post_voting_vote, votable: reply, user: user2, direction: "up") }

    it "moves comments and votes when the OP is moved" do
      original_topic.move_posts(
        admin,
        [op.id, reply.id],
        destination_topic_id: destination_topic.id,
      )

      new_op =
        destination_topic
          .posts
          .where.not(post_type: Post.types[:small_action])
          .order(:post_number)
          .first
      expect(new_op.id).not_to eq(op.id)

      expect(PostVotingComment.where(post_id: new_op.id).count).to eq(1)
      expect(PostVotingVote.where(votable_type: "Post", votable_id: new_op.id).count).to eq(1)

      expect(PostVotingComment.where(post_id: op.id).count).to eq(0)
      expect(PostVotingVote.where(votable_type: "Post", votable_id: op.id).count).to eq(0)
    end

    it "does not change data when post_id stays the same" do
      original_topic.move_posts(admin, [reply.id], destination_topic_id: destination_topic.id)

      reply.reload
      expect(reply.topic_id).to eq(destination_topic.id)
      expect(PostVotingComment.where(post_id: reply.id).count).to eq(1)
      expect(PostVotingVote.where(votable_type: "Post", votable_id: reply.id).count).to eq(1)
    end

    it "moves data with freeze_original" do
      PostMover.new(
        original_topic,
        admin,
        [op.id, reply.id],
        options: {
          freeze_original: true,
        },
      ).to_topic(destination_topic.id)

      moved_reply =
        destination_topic
          .posts
          .where.not(post_type: Post.types[:small_action])
          .order(:post_number)
          .last
      expect(moved_reply.id).not_to eq(reply.id)

      expect(PostVotingComment.where(post_id: moved_reply.id).count).to eq(1)
      expect(PostVotingVote.where(votable_type: "Post", votable_id: moved_reply.id).count).to eq(1)

      expect(PostVotingComment.where(post_id: reply.id).count).to eq(0)
      expect(PostVotingVote.where(votable_type: "Post", votable_id: reply.id).count).to eq(0)
    end
  end
end
