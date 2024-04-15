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
end
