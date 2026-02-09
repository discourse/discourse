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

    it "copies polls, options, and votes when the OP is moved to an existing topic" do
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
    end

    it "does not duplicate polls when post_id stays the same" do
      original_topic.move_posts(admin, [reply.id], destination_topic_id: destination_topic.id)

      reply.reload
      expect(reply.topic_id).to eq(destination_topic.id)
      expect(Poll.where(post_id: reply.id).count).to eq(1)
      expect(PollVote.where(poll_id: reply_poll.id).count).to eq(2)
    end

    it "preserves ranked choice vote ranks" do
      rc_poll = Fabricate(:poll, post: op, name: "rc_poll", type: "ranked_choice")
      rc_options = 3.times.map { |i| Fabricate(:poll_option, poll: rc_poll, html: "RC #{i}") }
      rc_options.each_with_index do |opt, i|
        Fabricate(:poll_vote, poll: rc_poll, poll_option: opt, user: user1, rank: i + 1)
      end

      original_topic.move_posts(admin, [op.id], destination_topic_id: destination_topic.id)

      new_op =
        destination_topic
          .posts
          .where.not(post_type: Post.types[:small_action])
          .order(:post_number)
          .last
      new_rc_poll = Poll.find_by(post_id: new_op.id, name: "rc_poll")
      expect(PollVote.where(poll_id: new_rc_poll.id).order(:rank).pluck(:rank)).to eq([1, 2, 3])
    end

    it "is idempotent when the event fires twice" do
      original_topic.move_posts(admin, [op.id], destination_topic_id: destination_topic.id)

      new_op =
        destination_topic
          .posts
          .where.not(post_type: Post.types[:small_action])
          .order(:post_number)
          .last

      expect {
        DiscourseEvent.trigger(:post_moved, new_op, original_topic.id, op)
      }.not_to raise_error
      expect(Poll.where(post_id: new_op.id, name: "op_poll").count).to eq(1)
    end

    it "copies polls to the new post and preserves originals with freeze_original" do
      PostMover.new(
        original_topic,
        admin,
        [op.id, reply.id],
        options: {
          freeze_original: true,
        },
      ).to_topic(destination_topic.id)

      new_op =
        destination_topic
          .posts
          .where.not(post_type: Post.types[:small_action])
          .order(:post_number)
          .first
      moved_reply =
        destination_topic
          .posts
          .where.not(post_type: Post.types[:small_action])
          .order(:post_number)
          .last

      [
        [new_op, op, "op_poll", op_poll],
        [moved_reply, reply, "reply_poll", reply_poll],
      ].each do |new_post, old_post, poll_name, original_poll|
        new_poll = Poll.find_by(post_id: new_post.id, name: poll_name)
        expect(new_poll).to be_present
        expect(new_poll.poll_options.count).to eq(2)
        expect(PollVote.where(poll_id: new_poll.id).count).to eq(2)

        expect(Poll.where(post_id: old_post.id, name: poll_name).count).to eq(1)
        expect(PollVote.where(poll_id: original_poll.id).count).to eq(2)
      end
    end
  end
end
