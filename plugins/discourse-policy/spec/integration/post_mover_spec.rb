# frozen_string_literal: true

RSpec.describe PostMover do
  fab!(:admin)

  before { SiteSetting.policy_enabled = true }

  describe "moving posts with policies" do
    fab!(:original_topic) { Fabricate(:topic, user: admin) }
    fab!(:destination_topic) { Fabricate(:topic, user: admin) }
    fab!(:op) { Fabricate(:post, topic: original_topic, user: admin) }
    fab!(:reply) { Fabricate(:post, topic: original_topic, user: admin) }

    fab!(:op_policy) { Fabricate(:post_policy, post: op) }
    fab!(:reply_policy) { Fabricate(:post_policy, post: reply) }

    it "moves policies when post_id changes" do
      new_post = Fabricate(:post, topic: destination_topic, user: admin)
      DiscourseEvent.trigger(:post_moved, new_post, original_topic.id, op)

      expect(PostPolicy.where(post_id: new_post.id).count).to eq(1)
      expect(PostPolicy.where(post_id: op.id).count).to eq(0)
    end

    it "does not change data when post_id stays the same" do
      DiscourseEvent.trigger(:post_moved, reply, original_topic.id, reply)

      expect(PostPolicy.where(post_id: reply.id).count).to eq(1)
    end

    it "is a no-op when old_post is blank" do
      new_post = Fabricate(:post, topic: destination_topic, user: admin)
      expect {
        DiscourseEvent.trigger(:post_moved, new_post, original_topic.id, nil)
      }.not_to raise_error
    end
  end
end
