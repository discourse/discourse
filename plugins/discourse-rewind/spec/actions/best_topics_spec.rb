# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::BestTopics do
  fab!(:date) { Date.new(2021).all_year }
  fab!(:user)
  fab!(:topic_1) { Fabricate(:topic, user: user, created_at: random_datetime) }
  fab!(:topic_2) { Fabricate(:topic, user: user, created_at: random_datetime) }
  fab!(:topic_3) { Fabricate(:topic, user: user, created_at: random_datetime) }
  fab!(:topic_4) { Fabricate(:topic, user: user, created_at: random_datetime) }
  fab!(:topic_5) { Fabricate(:topic, user: user, created_at: random_datetime) }

  before { TopTopic.refresh! }

  describe ".call" do
    it "returns top 3 topics ordered by yearly_score" do
      [topic_1, topic_2, topic_3, topic_4, topic_5].each do |topic|
        topic.update!(created_at: random_datetime)
      end
      TopTopic.refresh!

      TopTopic.find_by(topic_id: topic_1.id).update!(yearly_score: 15)
      TopTopic.find_by(topic_id: topic_2.id).update!(yearly_score: 10)
      TopTopic.find_by(topic_id: topic_3.id).update!(yearly_score: 6)
      TopTopic.find_by(topic_id: topic_4.id).update!(yearly_score: 11)
      TopTopic.find_by(topic_id: topic_5.id).update!(yearly_score: 13)
      expect(call_report[:data]).to eq(
        [
          {
            topic_id: topic_1.id,
            title: topic_1.title,
            excerpt: topic_1.excerpt,
            yearly_score: 15.0,
          },
          {
            topic_id: topic_5.id,
            title: topic_5.title,
            excerpt: topic_5.excerpt,
            yearly_score: 13.0,
          },
          {
            topic_id: topic_4.id,
            title: topic_4.title,
            excerpt: topic_4.excerpt,
            yearly_score: 11.0,
          },
        ],
      )
    end

    context "when a topic is deleted" do
      before { topic_1.trash!(Discourse.system_user) }

      it "is not included" do
        expect(call_report[:data].map { |d| d[:topic_id] }).not_to include(topic_1.id)
      end
    end

    context "when a topic" do
      before { topic_1.update!(user: Fabricate(:user)) }

      it "is not included" do
        expect(call_report[:data].map { |d| d[:topic_id] }).not_to include(topic_1.id)
      end
    end

    context "when a topic is a private message" do
      fab!(:pm_topic) { Fabricate(:private_message_topic, user: user, created_at: random_datetime) }

      before do
        TopTopic.refresh!
        TopTopic.find_by(topic_id: pm_topic.id)&.update!(yearly_score: 99)
      end

      it "is not included" do
        expect(call_report[:data].map { |d| d[:topic_id] }).not_to include(pm_topic.id)
      end
    end
  end
end
