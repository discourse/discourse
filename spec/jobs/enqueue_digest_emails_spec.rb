# frozen_string_literal: true

require 'rails_helper'

describe Jobs::EnqueueDigestEmails do

  describe '#target_users' do

    context 'disabled digests' do
      before { SiteSetting.default_email_digest_frequency = 0 }
      let!(:user_no_digests) { Fabricate(:active_user, last_emailed_at: 8.days.ago, last_seen_at: 10.days.ago) }

      it "doesn't return users with email disabled" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user_no_digests.id)).to eq(false)
      end
    end

    context 'unapproved users' do

      before do
        SiteSetting.must_approve_users = true
      end

      let!(:unapproved_user) { Fabricate(:active_user, approved: false, last_emailed_at: 8.days.ago, last_seen_at: 10.days.ago) }

      it 'should enqueue the right digest emails' do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(false)

        # As a moderator
        unapproved_user.update_column(:moderator, true)
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(true)

        # As an admin
        unapproved_user.update(admin: true, moderator: false)
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(true)

        # As an approved user
        unapproved_user.update(admin: false, moderator: false, approved: true)
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(true)
      end
    end

    context 'staged users' do
      let!(:staged_user) { Fabricate(:active_user, staged: true, last_emailed_at: 1.year.ago, last_seen_at: 1.year.ago) }

      it "doesn't return staged users" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(staged_user.id)).to eq(false)
      end
    end

    context 'recently emailed' do
      let!(:user_emailed_recently) { Fabricate(:active_user, last_emailed_at: 6.days.ago) }

      it "doesn't return users who have been emailed recently" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user_emailed_recently.id)).to eq(false)
      end

    end

    context "inactive user" do
      let!(:inactive_user) { Fabricate(:user, active: false) }

      it "doesn't return users who have been emailed recently" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(inactive_user.id)).to eq(false)
      end
    end

    context "suspended user" do
      let!(:suspended_user) { Fabricate(:user, suspended_till: 1.week.from_now, suspended_at: 1.day.ago) }

      it "doesn't return users who are suspended" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(suspended_user.id)).to eq(false)
      end
    end

    context 'visited the site this week' do
      let(:user_visited_this_week) { Fabricate(:active_user, last_seen_at: 6.days.ago) }

      it "doesn't return users who have been emailed recently" do
        user = user_visited_this_week
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user.id)).to eq(false)
      end
    end

    context 'visited the site a year ago' do
      let!(:user_visited_a_year_ago) { Fabricate(:active_user, last_seen_at: 370.days.ago) }

      it "doesn't return the user who have not visited the site for more than 365 days" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(user_visited_a_year_ago.id)).to eq(false)
      end
    end

    context 'regular users' do
      let!(:user) { Fabricate(:active_user, last_seen_at: 360.days.ago) }

      it "returns the user" do
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids).to eq([user.id])
      end
    end

    context 'too many bounces' do
      let!(:bounce_user) { Fabricate(:active_user, last_seen_at: 6.month.ago) }

      it "doesn't return users with too many bounces" do
        bounce_user.user_stat.update(bounce_score: SiteSetting.bounce_score_threshold + 1)
        expect(Jobs::EnqueueDigestEmails.new.target_user_ids.include?(bounce_user.id)).to eq(false)
      end
    end

  end

  describe '#execute' do

    let(:user) { Fabricate(:user) }

    context "digest emails are enabled" do
      before do
        Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).returns([user.id])
      end

      it "enqueues the digest email job" do
        SiteSetting.disable_digest_emails = false
        Jobs.expects(:enqueue).with(:user_email, type: :digest, user_id: user.id)
        Jobs::EnqueueDigestEmails.new.execute({})
      end
    end

    context "private email" do
      before do
        Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).never
        SiteSetting.private_email = true
        Jobs.expects(:enqueue).with(:user_email, type: :digest, user_id: user.id).never
      end
      it "doesn't return users with email disabled" do
        Jobs::EnqueueDigestEmails.new.execute({})
      end
    end

    context "digest emails are disabled" do
      before do
        Jobs::EnqueueDigestEmails.any_instance.expects(:target_user_ids).never
        SiteSetting.disable_digest_emails = true
      end

      it "does not enqueue the digest email job" do
        Jobs.expects(:enqueue).with(:user_email, type: :digest, user_id: user.id).never
        Jobs::EnqueueDigestEmails.new.execute({})
      end
    end

  end

end
