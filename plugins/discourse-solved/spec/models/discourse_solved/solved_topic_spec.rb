# frozen_string_literal: true

RSpec.describe DiscourseSolved::SolvedTopic do
  fab!(:topic, :topic_with_op)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user)

  before { SiteSetting.allow_solved_on_all_topics = true }

  describe "Associations" do
    it { is_expected.to belong_to(:topic) }
    it { is_expected.to have_many(:topic_answers) }
    it { is_expected.to have_many(:answer_posts) }
    it { is_expected.to belong_to(:topic_timer).dependent(:destroy) }
  end

  describe "Validations" do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe "Callbacks" do
    describe "#auto_close_topic_timer" do
      subject(:solved) { described_class.create(topic:) }

      context "when auto close hours is greater than zero" do
        before { SiteSetting.solved_topics_auto_close_hours = 2 }

        it "creates a silent close timer based on last post" do
          expect(solved.topic_timer).to have_attributes(
            topic:,
            status_type: TopicTimer.types[:silent_close],
            based_on_last_post: true,
            duration_minutes: 120,
          )
        end

        context "when the topic is already closed" do
          before { topic.update!(closed: true) }

          it "does not create a timer" do
            expect(solved.topic_timer).to be_nil
          end
        end
      end

      context "when auto close hours is zero" do
        before { SiteSetting.solved_topics_auto_close_hours = 0 }

        it "does not create a timer" do
          expect(solved.topic_timer).to be_nil
        end
      end

      context "when category overrides auto close hours" do
        fab!(:category)

        before do
          topic.update!(category:)
          category.custom_fields["solved_topics_auto_close_hours"] = 5
          category.save!
          SiteSetting.solved_topics_auto_close_hours = 2
        end

        it "uses the category value" do
          expect(solved.topic_timer).to have_attributes(duration_minutes: 300)
        end
      end

      describe "with multiple solutions enabled" do
        fab!(:post2) { Fabricate(:post, topic: topic) }
        before do
          SiteSetting.solved_allow_multiple_solutions = true
          SiteSetting.solved_topics_auto_close_hours = 2
        end

        it "only creates one timer" do
          expect(solved.topic_timer).to have_attributes(
            topic:,
            status_type: TopicTimer.types[:silent_close],
            based_on_last_post: true,
            duration_minutes: 120,
          )

          topic_timer_id = solved.topic_timer.id
          Fabricate(:topic_answer, solved_topic: solved, post: post2)

          expect(solved.reload.topic_timer.id).to eq(topic_timer_id)
        end
      end
    end
  end
end
