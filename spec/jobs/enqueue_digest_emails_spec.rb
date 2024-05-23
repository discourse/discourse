# frozen_string_literal: true

RSpec.describe Jobs::EnqueueDigestEmails do
  let(:job) { described_class.new }

  describe "#execute" do
    fab!(:user)

    context "when all emails are disabled" do
      before { SiteSetting.disable_emails = "yes" }

      it "does not enqueue the digest email job" do
        Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).never

        expect_not_enqueued_with(job: :user_email, args: { type: :digest, user_id: user.id }) do
          job.execute({})
        end
      end
    end

    context "when digest emails are disabled" do
      before { SiteSetting.disable_digest_emails = true }

      it "does not enqueue the digest email job" do
        Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).never

        expect_not_enqueued_with(job: :user_email, args: { type: :digest, user_id: user.id }) do
          job.execute({})
        end
      end
    end

    context "when emails are private" do
      before { SiteSetting.private_email = true }

      it "does not enqueue the digest email job" do
        Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).never

        expect_not_enqueued_with(job: :user_email, args: { type: :digest, user_id: user.id }) do
          job.execute({})
        end
      end
    end
  end

  describe "#target_user_ids" do
    fab!(:user) { Fabricate(:active_user, last_seen_at: 10.days.ago) }
    fab!(:bot) { Fabricate(:bot, last_seen_at: 10.days.ago) }
    fab!(:anon) { Fabricate(:anonymous, last_seen_at: 10.days.ago) }

    it "never returns bots" do
      expect(job.target_user_ids).not_to include(bot.id)
    end

    it "never returns anonymous users" do
      expect(job.target_user_ids).not_to include(anon.id)
    end

    it "never returns inactive users" do
      user.update!(active: false)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns staged users" do
      user.update!(staged: true)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns suspended users" do
      user.update!(suspended_till: 1.day.from_now)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns users who have not opted in to digest emails" do
      user.user_option.update!(email_digests: false)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns users who have set a digest frequency to 'never" do
      user.user_option.update!(digest_after_minutes: 0)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns users who have not set a digest frequency and it's disabled globally" do
      SiteSetting.default_email_digest_frequency = 0
      user.user_option.update!(digest_after_minutes: nil)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns users who have a bounce score above the threshold" do
      user.user_stat.update!(bounce_score: SiteSetting.bounce_score_threshold + 1)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns users who doesn't have a primary email" do
      user.user_emails.update_all(primary: false)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns users who have received a digest email too recently" do
      user.user_stat.update!(digest_attempted_at: 1.minute.ago)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns users who have been seen too recently" do
      user.update!(last_seen_at: 1.minute.ago)
      expect(job.target_user_ids).not_to include(user.id)
    end

    it "never returns users who have been seen too long ago" do
      user.update!(last_seen_at: (SiteSetting.suppress_digest_email_after_days + 1).days.ago)
      expect(job.target_user_ids).not_to include(user.id)
    end

    context "when the site requires user approval" do
      before { SiteSetting.must_approve_users = true }

      it "never returns users who have not been approved" do
        user.update!(approved: false)
        expect(job.target_user_ids).not_to include(user.id)
      end

      it "returns users who have been approved" do
        user.update!(approved: true)
        expect(job.target_user_ids).to include(user.id)
      end

      it "always returns moderators" do
        user.update!(approved: false, moderator: true)
        expect(job.target_user_ids).to include(user.id)
      end

      it "always returns admins" do
        user.update!(approved: false, admin: true)
        expect(job.target_user_ids).to include(user.id)
      end
    end

    it "limits the number of users returned" do
      global_setting :max_digests_enqueued_per_30_mins_per_site, 1
      2.times { Fabricate(:active_user, last_seen_at: 10.days.ago) }
      expect(job.target_user_ids.size).to eq(1)
    end

    it "returns the user ids of users who want to receive digest emails" do
      expect(job.target_user_ids).to eq([user.id])
    end
  end
end
