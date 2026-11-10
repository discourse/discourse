# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::BestTopics do
  fab!(:user)
  fab!(:topic_1) { Fabricate(:topic, user: user, created_at: random_datetime) }
  fab!(:topic_2) { Fabricate(:topic, user: user, created_at: random_datetime) }
  fab!(:topic_3) { Fabricate(:topic, user: user, created_at: random_datetime) }
  fab!(:topic_4) { Fabricate(:topic, user: user, created_at: random_datetime) }
  fab!(:topic_5) { Fabricate(:topic, user: user, created_at: random_datetime) }

  describe ".call" do
    before { TopTopic.refresh! }

    it "returns top 3 topics ordered by yearly_score" do
      TopTopic.find_by(topic_id: topic_1.id).update!(yearly_score: 15)
      TopTopic.find_by(topic_id: topic_2.id).update!(yearly_score: 10)
      TopTopic.find_by(topic_id: topic_3.id).update!(yearly_score: 6)
      TopTopic.find_by(topic_id: topic_4.id).update!(yearly_score: 11)
      TopTopic.find_by(topic_id: topic_5.id).update!(yearly_score: 13)

      expect(call_report[:data]).to eq(
        [topic_1, topic_5, topic_4].map do |topic|
          { topic_id: topic.id, title: topic.title, excerpt: topic.excerpt }
        end,
      )
    end

    it "only includes the user's publicly visible topics" do
      topic_1.update!(user: Fabricate(:user))
      topic_2.update!(visible: false)

      expect(call_report[:data].pluck(:topic_id)).to contain_exactly(
        topic_3.id,
        topic_4.id,
        topic_5.id,
      )
    end
  end

  describe ".filter_for_viewer" do
    fab!(:group)
    fab!(:viewer) { Fabricate(:user).tap { |viewer| group.add(viewer) } }

    it "only keeps public topics the viewer can see" do
      topics = [
        Fabricate(:topic, category: Fabricate(:private_category, group:)),
        Fabricate(:shared_draft).topic,
        topic_1,
      ]
      report = { data: topics.map { |topic| { topic_id: topic.id } }, identifier: "best-topics" }

      filtered =
        described_class.filter_for_viewer(report, guardian: viewer.guardian, for_user: user)

      expect(filtered[:data]).to contain_exactly(topic_id: topic_1.id)
    end
  end
end
