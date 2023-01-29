# frozen_string_literal: true

RSpec.describe Jobs::EnqueueDigestEmails do
  describe "#target_users" do
    context "with disabled digests" do
      before { SiteSetting.default_email_digest_frequency = 0 }
      let!(:user_no_digests) do
        Fabricate(:active_user, last_emailed_at: 8.days.ago, last_seen_at: 10.days.ago)
      end

      it "doesn't return users with email disabled" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user_no_digests.id)).to eq(
          false,
        )
      end
    end

    context "with unapproved users" do
      before { SiteSetting.must_approve_users = true }

      let!(:unapproved_user) do
        Fabricate(
          :active_user,
          approved: false,
          last_emailed_at: 8.days.ago,
          last_seen_at: 10.days.ago,
        )
      end

      it "should enqueue the right digest emails" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(
          false,
        )

        # As a moderator
        unapproved_user.update_column(:moderator, true)
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(
          true,
        )

        # As an admin
        unapproved_user.update(admin: true, moderator: false)
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(
          true,
        )

        # As an approved user
        unapproved_user.update(admin: false, moderator: false, approved: true)
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(
          true,
        )
      end
    end

    context "with staged users" do
      let!(:staged_user) do
        Fabricate(:active_user, staged: true, last_emailed_at: 1.year.ago, last_seen_at: 1.year.ago)
      end

      it "doesn't return staged users" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(staged_user.id)).to eq(false)
      end
    end

    context "when recently emailed" do
      let!(:user_emailed_recently) { Fabricate(:active_user, last_emailed_at: 6.days.ago) }

      it "doesn't return users who have been emailed recently" do
        expect(
          Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user_emailed_recently.id),
        ).to eq(false)
      end
    end

    context "with inactive user" do
      let!(:inactive_user) { Fabricate(:user, active: false) }

      it "doesn't return users who have been emailed recently" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(inactive_user.id)).to eq(
          false,
        )
      end
    end

    context "with suspended user" do
      let!(:suspended_user) do
        Fabricate(:user, suspended_till: 1.week.from_now, suspended_at: 1.day.ago)
      end

      it "doesn't return users who are suspended" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(suspended_user.id)).to eq(
          false,
        )
      end
    end

    context "when visited the site this week" do
      let(:user_visited_this_week) { Fabricate(:active_user, last_seen_at: 6.days.ago) }

      it "doesn't return users who have been emailed recently" do
        user = user_visited_this_week
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user.id)).to eq(false)
      end
    end

    context "when visited the site a year ago" do
      let!(:user_visited_a_year_ago) { Fabricate(:active_user, last_seen_at: 370.days.ago) }

      it "doesn't return the user who have not visited the site for more than 365 days" do
        expect(
          Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user_visited_a_year_ago.id),
        ).to eq(false)
      end
    end

    context "with regular users" do
      let!(:user) do
        Fabricate(
          :active_user,
          last_seen_at: (SiteSetting.suppress_digest_email_after_days - 1).days.ago,
        )
      end

      it "returns the user" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids).to eq([user.id])
      end
    end

    context "with too many bounces" do
      let!(:bounce_user) { Fabricate(:active_user, last_seen_at: 6.month.ago) }

      it "doesn't return users with too many bounces" do
        bounce_user.user_stat.update(bounce_score: SiteSetting.bounce_score_threshold + 1)
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(bounce_user.id)).to eq(false)
      end
    end

    context "with no primary email" do
      let!(:user) { Fabricate(:active_user, last_seen_at: 2.months.ago) }

      it "doesn't return users with no primary emails" do
        UserEmail.where(user: user).delete_all
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user.id)).to eq(false)
      end
    end
  end

  describe "#execute" do
    let(:user) { Fabricate(:user) }

    it "limits jobs enqueued per max_digests_enqueued_per_30_mins_per_site" do
      user1 = Fabricate(:user, last_seen_at: 2.months.ago, last_emailed_at: 2.months.ago)
      user2 = Fabricate(:user, last_seen_at: 2.months.ago, last_emailed_at: 2.months.ago)

      user1.user_stat.update(digest_attempted_at: 2.week.ago)
      user2.user_stat.update(digest_attempted_at: 3.weeks.ago)

      global_setting :max_digests_enqueued_per_30_mins_per_site, 1

      expect_enqueued_with(job: :user_email, args: { type: :digest, user_id: user2.id }) do
        expect { Jobs::EnqueueDigestEmails.new.execute(nil) }.to change(
          Jobs::UserEmail.jobs,
          :size,
        ).by (1)
      end

      # The job didn't actually run, so fake the user_stat update
      user2.user_stat.update(digest_attempted_at: Time.zone.now)

      expect_enqueued_with(job: :user_email, args: { type: :digest, user_id: user1.id }) do
        expect { Jobs::EnqueueDigestEmails.new.execute(nil) }.to change(
          Jobs::UserEmail.jobs,
          :size,
        ).by (1)
      end

      user1.user_stat.update(digest_attempted_at: Time.zone.now)

      expect_not_enqueued_with(job: :user_email) { Jobs::EnqueueDigestEmails.new.execute(nil) }
    end

    context "when digest emails are enabled" do
      before { Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).returns([user.id]) }

      it "enqueues the digest email job" do
        SiteSetting.disable_digest_emails = false

        expect_enqueued_with(job: :user_email, args: { type: :digest, user_id: user.id }) do
          Jobs::EnqueueDigestEmails.new.execute({})
        end
      end
    end

    context "with private email" do
      before do
        Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).never
        SiteSetting.private_email = true
      end

      it "doesn't return users with email disabled" do
        expect_not_enqueued_with(job: :user_email, args: { type: :digest, user_id: user.id }) do
          Jobs::EnqueueDigestEmails.new.execute({})
        end
      end
    end

    context "when digest emails are disabled" do
      before do
        Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).never
        SiteSetting.disable_digest_emails = true
      end

      it "does not enqueue the digest email job" do
        expect_not_enqueued_with(job: :user_email, args: { type: :digest, user_id: user.id }) do
          Jobs::EnqueueDigestEmails.new.execute({})
        end
      end
    end
  end
end
