# frozen_string_literal: true

RSpec.describe DiscourseSolved::AcceptedAnswersHelper do
  before { SiteSetting.allow_solved_on_all_topics = true }

  fab!(:topic)
  fab!(:answer_post) { Fabricate(:post, topic:) }
  fab!(:accepter, :user)
  fab!(:user)

  describe "#serialize" do
    describe "with an accepted solution" do
      fab!(:solved_topic) { Fabricate(:solved_topic, topic:) }
      fab!(:topic_answer) { Fabricate(:topic_answer, solved_topic:, post: answer_post, accepter:) }

      it "returns the accepted solution info" do
        accepted_answers =
          DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, Guardian.new(user))

        expect(accepted_answers.length).to eq(1)

        expected_answer = {
          id: answer_post.id,
          username: answer_post.user.username,
          avatar_template: answer_post.user.avatar_template,
          created_at: answer_post.created_at,
          cooked: answer_post.cooked,
          post_number: answer_post.post_number,
          topic_id: answer_post.topic_id,
          url: answer_post.url,
        }

        expect(accepted_answers.first).to eq(expected_answer)
      end

      context "when users are deleted" do
        it "does not crash when accepter is deleted" do
          accepter.destroy!

          accepted_answers = nil

          expect {
            accepted_answers =
              DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, Guardian.new(user))
          }.not_to raise_error
          expect(accepted_answers).not_to be_empty
        end

        it "does not crash when answer post user is deleted" do
          answer_post.user.destroy!

          accepted_answers = nil

          expect {
            accepted_answers =
              DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, Guardian.new(user))
          }.not_to raise_error
          expect(accepted_answers.first[:username]).to eq(Discourse.system_user.username)
        end

        it "falls back to system user when both accepter and topic author are deleted" do
          SiteSetting.show_who_marked_solved = true
          accepter.destroy!
          topic.user.destroy!

          accepted_answers = nil

          expect {
            accepted_answers =
              DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, Guardian.new(user))
          }.not_to raise_error
          expect(accepted_answers.first[:accepter_username]).to eq(Discourse.system_user.username)
        end

        it "returns nil when answer post is deleted" do
          answer_post.destroy!

          accepted_answers = nil

          expect {
            accepted_answers =
              DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, Guardian.new(user))
          }.not_to raise_error
          expect(accepted_answers).to be_nil
        end
      end
    end

    describe "with multiple solutions enabled" do
      fab!(:solved_topic) { Fabricate(:solved_topic, topic:) }
      fab!(:topic_answer) { Fabricate(:topic_answer, solved_topic:, post: answer_post, accepter:) }
      fab!(:answer_post2) { Fabricate(:post, topic:) }
      fab!(:topic_answer2) do
        Fabricate(:topic_answer, solved_topic:, post: answer_post2, accepter:)
      end

      before { SiteSetting.solved_allow_multiple_solutions = true }

      it "returns the accepted solution info in order" do
        accepted_answers =
          DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, Guardian.new(user))

        expect(accepted_answers.length).to eq(2)

        expected_answers = [
          {
            id: answer_post.id,
            username: answer_post.user.username,
            avatar_template: answer_post.user.avatar_template,
            created_at: answer_post.created_at,
            cooked: answer_post.cooked,
            post_number: answer_post.post_number,
            topic_id: answer_post.topic_id,
            url: answer_post.url,
          },
          {
            id: answer_post2.id,
            username: answer_post2.user.username,
            avatar_template: answer_post2.user.avatar_template,
            created_at: answer_post2.created_at,
            cooked: answer_post2.cooked,
            post_number: answer_post2.post_number,
            topic_id: answer_post2.topic_id,
            url: answer_post2.url,
          },
        ]
        expect(accepted_answers).to eq(expected_answers)
      end

      context "when users are deleted" do
        it "keeps other answer when answer post is deleted" do
          accepted_answers = nil

          expect {
            accepted_answers =
              DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, Guardian.new(user))
          }.not_to raise_error

          expect(accepted_answers.length).to eq(2)

          # Destroying answer_post would delete the whole topic, since it's the OP
          PostDestroyer.new(Discourse.system_user, answer_post2, context: "test").destroy

          expect {
            accepted_answers =
              DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, Guardian.new(user))
          }.not_to raise_error
          expect(accepted_answers.length).to eq(1)
        end
      end
    end

    it "returns nil when topic is not solved" do
      expect(
        DiscourseSolved::AcceptedAnswersHelper.serialize(topic.reload, Guardian.new(user)),
      ).to be_nil
    end
  end
end
