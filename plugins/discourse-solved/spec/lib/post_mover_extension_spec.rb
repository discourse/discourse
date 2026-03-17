# frozen_string_literal: true

RSpec.describe DiscourseSolved::PostMoverExtension do
  fab!(:admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic_with_op, category: category) }
  fab!(:reply) { Fabricate(:post, topic: topic) }
  fab!(:another_reply) { Fabricate(:post, topic: topic) }
  fab!(:destination_topic) { Fabricate(:topic_with_op, category: category) }

  let!(:post_ids) { topic.posts.pluck(:id) }
  let!(:solved) { Fabricate(:solved_topic, topic: topic, answer_post: reply) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  context "when moving the solution post" do
    it "transfers the solution to an existing topic" do
      topic.move_posts(admin, post_ids, destination_topic_id: destination_topic.id)

      expect(solved.reload.topic_id).to eq(destination_topic.id)
    end

    it "transfers the solution to a new topic" do
      topic.move_posts(admin, [reply.id], title: "This is a new topic for the moved post")

      expect(topic.reload.solved).to be_nil
      expect(solved.reload.topic_id).not_to eq(topic.id)
    end

    it "does not transfer the solution when destination topic does not allow solved" do
      SiteSetting.allow_solved_on_all_topics = false

      topic.move_posts(admin, post_ids, destination_topic_id: destination_topic.id)

      expect(topic.reload.solved).to be_nil
      expect(destination_topic.reload.solved).to be_nil
    end

    it "does not transfer the solution when the destination topic already has a solution" do
      Fabricate(:solved_topic, topic: destination_topic, answer_post: destination_topic.first_post)

      topic.move_posts(admin, post_ids, destination_topic_id: destination_topic.id)

      expect(topic.reload.solved).to be_nil
      expect(destination_topic.reload.solved.answer_post_id).not_to eq(reply.id)
    end
  end

  context "when not moving the solution post" do
    it "keeps the solution on the original topic" do
      topic.move_posts(admin, [post_ids.first], destination_topic_id: destination_topic.id)

      expect(solved.reload.topic_id).to eq(topic.id)
    end

    it "keeps the solution when moving to a new topic" do
      topic.move_posts(admin, [another_reply.id], title: "This is a new topic for the moved post")

      expect(solved.reload.topic_id).to eq(topic.id)
    end

    it "does not affect the destination topic's solution" do
      Fabricate(:solved_topic, topic: destination_topic, answer_post: destination_topic.first_post)

      topic.move_posts(admin, [another_reply.id], destination_topic_id: destination_topic.id)

      expect(solved.reload.topic_id).to eq(topic.id)
      expect(destination_topic.reload.solved.answer_post_id).to eq(destination_topic.first_post.id)
    end
  end
end
