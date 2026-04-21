# frozen_string_literal: true

RSpec.describe DiscourseSolved::TopicExtension do
  before { SiteSetting.allow_solved_on_all_topics = true }

  fab!(:topic)
  fab!(:answer_post) { Fabricate(:post, topic:) }
  fab!(:accepter, :user)

  describe "#accepted_answer_post_info" do
    let(:solved_topic) { Fabricate(:solved_topic, topic:) }
    let(:topic_answer) { Fabricate(:topic_answer, solved_topic:, post: answer_post, accepter:) }

    context "when users are deleted" do
      it "does not crash when accepter is deleted" do
        solved_topic
        topic_answer
        accepter.destroy!

        expect { topic.reload.accepted_answers_post_info }.not_to raise_error
        expect(topic.accepted_answers_post_info).not_to be_empty
      end

      it "does not crash when answer post user is deleted" do
        solved_topic
        topic_answer
        answer_post.user.destroy!

        expect { topic.reload.accepted_answers_post_info }.not_to raise_error
        expect(topic.accepted_answers_post_info.first[:username]).to eq(
          Discourse.system_user.username,
        )
      end

      it "falls back to system user when both accepter and topic author are deleted" do
        SiteSetting.show_who_marked_solved = true
        solved_topic
        topic_answer
        accepter.destroy!
        topic.user.destroy!

        expect { topic.reload.accepted_answers_post_info }.not_to raise_error
        expect(topic.accepted_answers_post_info.first[:accepter_username]).to eq(
          Discourse.system_user.username,
        )
      end

      it "returns nil when answer post is deleted" do
        solved_topic
        answer_post.destroy!

        expect { topic.reload.accepted_answers_post_info }.not_to raise_error
        expect(topic.accepted_answers_post_info).to be_empty
      end
    end

    it "returns nil when topic is not solved" do
      expect(topic.accepted_answers_post_info).to be_empty
    end
  end
end
