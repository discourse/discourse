# frozen_string_literal: true

RSpec.describe PostMover do
  fab!(:admin)
  fab!(:user1, :user)
  fab!(:user2, :user)

  describe "moving posts with polls" do
    fab!(:original_topic) { Fabricate(:topic, user: admin) }
    fab!(:destination_topic) { Fabricate(:topic, user: admin) }

    fab!(:op) { Fabricate(:post, topic: original_topic, user: admin) }
    fab!(:reply) { Fabricate(:post, topic: original_topic, user: admin) }

    fab!(:op_poll) { Fabricate(:poll, post: op, name: "op_poll") }
    fab!(:op_poll_option1) { Fabricate(:poll_option, poll: op_poll, html: "Option A") }
    fab!(:op_poll_option2) { Fabricate(:poll_option, poll: op_poll, html: "Option B") }

    fab!(:reply_poll) { Fabricate(:poll, post: reply, name: "reply_poll") }
    fab!(:reply_poll_option1) { Fabricate(:poll_option, poll: reply_poll, html: "Option X") }
    fab!(:reply_poll_option2) { Fabricate(:poll_option, poll: reply_poll, html: "Option Y") }

    before do
      Jobs.run_immediately!

      Fabricate(:poll_vote, poll: op_poll, poll_option: op_poll_option1, user: user1)
      Fabricate(:poll_vote, poll: op_poll, poll_option: op_poll_option2, user: user2)

      Fabricate(:poll_vote, poll: reply_poll, poll_option: reply_poll_option1, user: user1)
      Fabricate(:poll_vote, poll: reply_poll, poll_option: reply_poll_option2, user: user2)

      op.custom_fields[DiscoursePoll::HAS_POLLS] = true
      op.save_custom_fields
      reply.custom_fields[DiscoursePoll::HAS_POLLS] = true
      reply.save_custom_fields
    end

    it "moves polls, options, and votes when the OP is moved to an existing topic" do
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

      new_poll = Poll.find_by(post_id: new_op.id)
      expect(new_poll.name).to eq("op_poll")
      expect(new_poll.poll_options.count).to eq(2)

      new_votes = PollVote.where(poll_id: new_poll.id)
      expect(new_votes.count).to eq(2)
      expect(new_votes.pluck(:user_id)).to contain_exactly(user1.id, user2.id)

      expect(Poll.where(post_id: op.id).count).to eq(0)
    end

    it "does not duplicate polls when post_id stays the same" do
      original_topic.move_posts(admin, [reply.id], destination_topic_id: destination_topic.id)

      reply.reload
      expect(reply.topic_id).to eq(destination_topic.id)
      expect(Poll.where(post_id: reply.id).count).to eq(1)
      expect(PollVote.where(poll_id: reply_poll.id).count).to eq(2)
    end

    it "moves polls to the new post and removes from old post with freeze_original" do
      PostMover.new(original_topic, admin, [reply.id], options: { freeze_original: true }).to_topic(
        destination_topic.id,
      )

      moved_reply =
        destination_topic
          .posts
          .where.not(post_type: Post.types[:small_action])
          .order(:post_number)
          .last
      expect(moved_reply.id).not_to eq(reply.id)

      expect(Poll.find_by(post_id: moved_reply.id, name: "reply_poll")).to be_present
      expect(PollVote.where(poll_id: Poll.find_by(post_id: moved_reply.id).id).count).to eq(2)

      expect(Poll.where(post_id: reply.id).count).to eq(0)
    end
  end
end
