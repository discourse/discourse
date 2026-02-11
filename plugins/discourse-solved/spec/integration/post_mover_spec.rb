# frozen_string_literal: true

RSpec.describe PostMover do
  fab!(:admin)

  before { Jobs.run_immediately! }

  describe "moving posts with solved data" do
    fab!(:original_topic) { Fabricate(:topic, user: admin) }
    fab!(:destination_topic) { Fabricate(:topic, user: admin) }
    fab!(:op) { Fabricate(:post, topic: original_topic, user: admin) }
    fab!(:answer) { Fabricate(:post, topic: original_topic, user: admin) }

    fab!(:solved_topic) do
      Fabricate(:solved_topic, topic: original_topic, answer_post: answer, accepter: admin)
    end

    it "retains the solved reference when post_id stays the same" do
      original_topic.move_posts(admin, [answer.id], destination_topic_id: destination_topic.id)

      answer.reload
      expect(answer.topic_id).to eq(destination_topic.id)

      solved_topic.reload
      expect(solved_topic.answer_post_id).to eq(answer.id)
    end

    it "updates answer_post_id when the answer gets a new post_id via freeze_original" do
      PostMover.new(
        original_topic,
        admin,
        [answer.id],
        options: {
          freeze_original: true,
        },
      ).to_topic(destination_topic.id)

      moved_answer =
        destination_topic
          .posts
          .where.not(post_type: Post.types[:small_action])
          .order(:post_number)
          .last
      expect(moved_answer.id).not_to eq(answer.id)

      solved_topic.reload
      expect(solved_topic.answer_post_id).to eq(moved_answer.id)

      expect(DiscourseSolved::SolvedTopic.where(answer_post_id: answer.id).count).to eq(0)
    end

    it "updates answer_post_id via direct event trigger" do
      new_post = Fabricate(:post, topic: destination_topic, user: admin)
      DiscourseEvent.trigger(:post_moved, new_post, original_topic.id, answer)

      solved_topic.reload
      expect(solved_topic.answer_post_id).to eq(new_post.id)

      expect(DiscourseSolved::SolvedTopic.where(answer_post_id: answer.id).count).to eq(0)
    end
  end
end
