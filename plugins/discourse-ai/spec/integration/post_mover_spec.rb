# frozen_string_literal: true

RSpec.describe PostMover do
  fab!(:admin)

  before do
    SiteSetting.discourse_ai_enabled = true
    Jobs.run_immediately!
  end

  describe "moving posts with AI data" do
    fab!(:original_topic) { Fabricate(:topic, user: admin) }
    fab!(:destination_topic) { Fabricate(:topic, user: admin) }
    fab!(:op) { Fabricate(:post, topic: original_topic, user: admin) }
    fab!(:reply) { Fabricate(:post, topic: original_topic, user: admin) }

    fab!(:artifact) { Fabricate(:ai_artifact, post: op) }
    fab!(:classification) do
      Fabricate(:classification_result, target: op, classification_type: "sentiment")
    end
    fab!(:summary) { Fabricate(:ai_summary, target: op, summary_type: :complete) }

    it "moves AI data when the OP is moved" do
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

      expect(AiArtifact.where(post_id: new_op.id).count).to eq(1)
      expect(AiArtifact.where(post_id: op.id).count).to eq(0)

      expect(ClassificationResult.where(target_type: "Post", target_id: new_op.id).count).to eq(1)
      expect(ClassificationResult.where(target_type: "Post", target_id: op.id).count).to eq(0)

      expect(AiSummary.where(target_type: "Post", target_id: new_op.id).count).to eq(1)
      expect(AiSummary.where(target_type: "Post", target_id: op.id).count).to eq(0)
    end

    it "does not change data when post_id stays the same" do
      original_topic.move_posts(admin, [reply.id], destination_topic_id: destination_topic.id)

      reply.reload
      expect(reply.topic_id).to eq(destination_topic.id)
    end

    it "moves data with freeze_original" do
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
    end
  end
end
