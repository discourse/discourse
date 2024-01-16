# frozen_string_literal: true

RSpec.describe TopicHotScore do
  describe ".update_scores" do
    it "can correctly set scores for topics" do
      freeze_time

      topic1 = Fabricate(:topic, like_count: 3, created_at: 1.hour.ago)
      topic2 = Fabricate(:topic, like_count: 10, created_at: 3.hour.ago)

      TopicHotScore.update_scores

      expect(TopicHotScore.find_by(topic_id: topic1.id).score).to be_within(0.001).of(0.276)
      expect(TopicHotScore.find_by(topic_id: topic2.id).score).to be_within(0.001).of(0.496)

      freeze_time(2.hours.from_now)

      TopicHotScore.update_scores

      expect(TopicHotScore.find_by(topic_id: topic1.id).score).to be_within(0.001).of(0.110)
      expect(TopicHotScore.find_by(topic_id: topic2.id).score).to be_within(0.001).of(0.271)
    end
  end
end
