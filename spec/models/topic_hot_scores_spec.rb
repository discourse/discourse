# frozen_string_literal: true

RSpec.describe TopicHotScore do
  describe ".update_scores" do
    fab!(:user)
    fab!(:user2) { Fabricate(:user) }
    fab!(:user3) { Fabricate(:user) }

    it "also always updates based on recent activity" do
      freeze_time

      # this will come in with a score
      topic = Fabricate(:topic, created_at: 1.hour.ago, bumped_at: 2.minutes.ago)
      post = Fabricate(:post, topic: topic, created_at: 2.minute.ago)
      PostActionCreator.like(user, post)

      TopicHotScore.update_scores

      # this will come in in the batch in score 0
      topic = Fabricate(:topic, created_at: 1.minute.ago, bumped_at: 1.minute.ago)
      post = Fabricate(:post, topic: topic, created_at: 1.minute.ago)
      PostActionCreator.like(user, post)

      # batch size is 1 so if we do not do something special we only update
      # the high score topic and skip new
      TopicHotScore.update_scores(1)

      expect(TopicHotScore.find_by(topic_id: topic.id).score).to be_within(0.001).of(0.861)
    end

    it "can correctly update like counts and post counts and account for activity" do
      freeze_time_safe

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

      # user 3 likes two posts, but we should only count 1
      # this avoids a single user from trivially inflating hot scores
      PostActionCreator.like(user3, new_reply)
      PostActionCreator.like(user3, newer_reply)

      TopicHotScore.update_scores

      hot_scoring = TopicHotScore.find_by(topic_id: topic.id)

      expect(hot_scoring.recent_posters).to eq(2)
      expect(hot_scoring.recent_likes).to eq(3)
      expect(hot_scoring.recent_first_bumped_at).to eq_time(new_reply.created_at)
      expect(hot_scoring.score).to be_within(0.001).of(1.771)

      expect(TopicHotScore.find_by(topic_id: -1).recent_likes).to eq(0)

      # make sure we exclude whispers, deleted posts, small posts, etc
      whisper =
        Fabricate(:post, topic: topic, created_at: 1.hour.ago, post_type: Post.types[:whisper])
      PostActionCreator.like(Fabricate(:admin), whisper)

      TopicHotScore.update_scores

      hot_scoring = TopicHotScore.find_by(topic_id: topic.id)

      expect(hot_scoring.recent_posters).to eq(2)
      expect(hot_scoring.recent_likes).to eq(3)
    end

    it "prefers recent_likes to topic like count for recent topics" do
      freeze_time

      topic = Fabricate(:topic, created_at: 1.hour.ago)
      post = Fabricate(:post, topic: topic, created_at: 1.minute.ago)
      PostActionCreator.like(user, post)

      TopicHotScore.update_scores
      score = TopicHotScore.find_by(topic_id: topic.id).score

      topic.update!(like_count: 100)

      TopicHotScore.update_scores

      expect(TopicHotScore.find_by(topic_id: topic.id).score).to be_within(0.001).of(score)
    end

    it "can correctly set scores for topics" do
      freeze_time

      topic1 = Fabricate(:topic, like_count: 3, created_at: 2.weeks.ago)
      topic2 = Fabricate(:topic, like_count: 10, created_at: 2.weeks.ago)

      TopicHotScore.update_scores

      expect(TopicHotScore.find_by(topic_id: topic1.id).score).to be_within(0.001).of(0.002)
      expect(TopicHotScore.find_by(topic_id: topic2.id).score).to be_within(0.001).of(0.009)

      freeze_time(6.weeks.from_now)

      TopicHotScore.update_scores

      expect(TopicHotScore.find_by(topic_id: topic1.id).score).to be_within(0.0001).of(0.0005)
      expect(TopicHotScore.find_by(topic_id: topic2.id).score).to be_within(0.001).of(0.001)
    end

    it "ignores topics in the future" do
      freeze_time

      topic1 = Fabricate(:topic, like_count: 3, created_at: 2.days.from_now)
      post1 = Fabricate(:post, topic: topic1, created_at: 1.minute.ago)
      PostActionCreator.like(user, post1)
      TopicHotScore.create!(topic_id: topic1.id, score: 0.0, recent_likes: 0, recent_posters: 0)

      expect { TopicHotScore.update_scores }.not_to change {
        TopicHotScore.where(topic_id: topic1.id).pluck(:recent_likes)
      }
    end

    it "triggers an event after updating" do
      triggered = false
      blk = Proc.new { triggered = true }

      begin
        DiscourseEvent.on(:topic_hot_scores_updated, &blk)

        TopicHotScore.update_scores

        expect(triggered).to eq(true)
      ensure
        DiscourseEvent.off(:topic_hot_scores_updated, &blk)
      end
    end
  end
end
