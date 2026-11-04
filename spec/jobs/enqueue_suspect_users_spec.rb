# frozen_string_literal: true

RSpec.describe Jobs::EnqueueSuspectUsers do
  subject(:job) { described_class.new }

  before { SiteSetting.approve_suspect_users = true }

  it "does nothing when there are no suspect users" do
    job.execute({})

    expect(ReviewableUser.count).to be_zero
  end

  context "with suspect users" do
    let!(:suspect_user) { Fabricate(:active_user, created_at: 1.day.ago) }

    it "creates a reviewable when there is a suspect user" do
      job.execute({})

      expect(ReviewableUser.count).to eq(1)
    end

    it "only creates one reviewable per user" do
      review_user =
        ReviewableUser.needs_review!(
          target: suspect_user,
          created_by: Discourse.system_user,
          reviewable_by_moderator: true,
        )

      job.execute({})

      expect(ReviewableUser.count).to eq(1)
      expect(ReviewableUser.last).to eq(review_user)
    end

    it "adds a score" do
      job.execute({})
      score = ReviewableScore.last

      expect(score.reason).to eq("suspect_user")
    end

    it "only enqueues non-approved users" do
      suspect_user.update!(approved: true)

      job.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it "does nothing if must_approve_users is set to true" do
      SiteSetting.must_approve_users = true
      suspect_user.update!(approved: false)

      job.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it "ignores suspended users" do
      suspect_user.update!(suspended_till: 1.year.from_now)

      job.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it "ignores users created more than six months ago" do
      suspect_user.update!(created_at: 1.year.ago)

      job.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it "ignores users that were imported from another site" do
      suspect_user.upsert_custom_fields({ import_id: "fake_id" })

      job.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it "enqueues a suspect users with custom fields" do
      suspect_user.upsert_custom_fields({ field_a: "value", field_b: "value" })

      job.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(true)
    end

    it "ignores imported users even if they have multiple custom fields" do
      suspect_user.upsert_custom_fields(
        { field_a: "value", field_b: "value", import_id: "fake_id" },
      )

      job.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it "enqueues a suspect user with not enough time read" do
      suspect_user.user_stat.update!(
        posts_read_count: 2,
        topics_entered: 2,
        time_read: 30.seconds.to_i,
      )

      job.execute({})

      expect(ReviewableUser.count).to eq(1)
    end

    it "ignores users if their time read is higher than one minute" do
      suspect_user.user_stat.update!(
        posts_read_count: 2,
        topics_entered: 2,
        time_read: 2.minutes.to_i,
      )

      job.execute({})

      expect(ReviewableUser.count).to eq(0)
    end
  end

  context "with new users whose reads are in topics they never opened" do
    fab!(:user) { Fabricate(:active_user, created_at: 2.hours.ago) }
    fab!(:opened_topic, :topic)
    fab!(:unopened_topic, :topic)

    def read_posts(topic, count, from: 1)
      PostTiming.insert_all(
        (from...(from + count)).map do |post_number|
          { topic_id: topic.id, user_id: user.id, post_number:, msecs: 1000 }
        end,
      )
      user.user_stat.update!(posts_read_count: user.user_stat.posts_read_count + count)
    end

    before { TopicViewItem.add(opened_topic.id, "127.0.0.1", user.id, nil, true) }

    it "enqueues the user with the reads_without_topic_views reason" do
      read_posts(unopened_topic, 20)

      job.execute({})

      reviewable = ReviewableUser.find_by(target: user)
      expect(reviewable.reviewable_scores.map(&:reason)).to contain_exactly(
        "reads_without_topic_views",
      )
      expect(reviewable.is_a_suspect_user?).to eq(true)
    end

    it "ignores users whose reads are mostly in topics they opened" do
      read_posts(opened_topic, 18)
      read_posts(unopened_topic, 2)

      job.execute({})

      expect(ReviewableUser.exists?(target: user)).to eq(false)
    end

    it "ignores users with fewer than 20 reads" do
      read_posts(unopened_topic, 19)

      job.execute({})

      expect(ReviewableUser.exists?(target: user)).to eq(false)
    end

    it "ignores users who have posted" do
      read_posts(unopened_topic, 20)
      user.user_stat.update!(post_count: 1)

      job.execute({})

      expect(ReviewableUser.exists?(target: user)).to eq(false)
    end

    it "ignores accounts older than seven days" do
      read_posts(unopened_topic, 20)
      user.update!(created_at: 8.days.ago)

      job.execute({})

      expect(ReviewableScore.exists?(reason: "reads_without_topic_views")).to eq(false)
    end
  end
end
