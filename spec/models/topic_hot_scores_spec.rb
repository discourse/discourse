# frozen_string_literal: true

RSpec.describe TopicHotScore do
  describe ".update_scores" do
    fab!(:user)
    fab!(:user2) { Fabricate(:user) }

    it "can correctly update like counts and post counts and account for activity" do
      freeze_time

      TopicHotScore.create!(topic_id: -1, score: 0.0, recent_likes: 99, recent_posters: 0)

      old_post = Fabricate(:post, created_at: 10.months.ago)
      topic = old_post.topic

      new_reply = Fabricate(:post, user: user, topic: topic, created_at: 4.hours.ago)
      newer_reply = Fabricate(:post, user: user2, topic: topic, created_at: 1.hour.ago)
      Fabricate(:post, user: user2, topic: topic, created_at: 1.minute.ago)

      freeze_time(1.year.ago)
      PostActionCreator.like(user, old_post)
      freeze_time(1.year.from_now)

      PostActionCreator.like(user2, new_reply)
      PostActionCreator.like(user, newer_reply)

      TopicHotScore.update_scores

      hot_scoring = TopicHotScore.find_by(topic_id: topic.id)

      expect(hot_scoring.recent_likes).to eq(2)
      expect(hot_scoring.recent_posters).to eq(2)
      expect(hot_scoring.recent_first_bumped_at).to eq_time(new_reply.created_at)
      expect(hot_scoring.score).to be_within(0.001).of(1.219)

      expect(TopicHotScore.find_by(topic_id: -1).recent_likes).to eq(0)
    end

    it "can correctly set scores for topics" do
      freeze_time

      topic1 = Fabricate(:topic, like_count: 3, created_at: 1.hour.ago)
      topic2 = Fabricate(:topic, like_count: 10, created_at: 3.hour.ago)

      TopicHotScore.update_scores

      expect(TopicHotScore.find_by(topic_id: topic1.id).score).to be_within(0.001).of(0.535)
      expect(TopicHotScore.find_by(topic_id: topic2.id).score).to be_within(0.001).of(1.304)

      freeze_time(2.hours.from_now)

      TopicHotScore.update_scores

      expect(TopicHotScore.find_by(topic_id: topic1.id).score).to be_within(0.001).of(0.289)
      expect(TopicHotScore.find_by(topic_id: topic2.id).score).to be_within(0.001).of(0.871)
    end
  end
end
