require 'rails_helper'
require_dependency 'jobs/base'

describe Jobs::EnqueueMailingListEmails do

  describe '#target_users' do

    context 'disabled mailing list mode' do
      before { SiteSetting.disable_mailing_list_mode = true }
      let!(:user_no_digests) { Fabricate(:active_user) }

      it "doesn't return users with email disabled" do
        expect(Jobs::EnqueueMailingListEmails.new.target_user_ids.include?(user_no_digests.id)).to eq(false)
      end
    end

    context 'unapproved users' do
      Given!(:unapproved_user) { Fabricate(:active_user, approved: false) }
      When do
        SiteSetting.must_approve_users = true
        unapproved_user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 0)
      end
      Then { expect(Jobs::EnqueueMailingListEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(false) }

      # As a moderator
      And { unapproved_user.update_column(:moderator, true) }
      And { expect(Jobs::EnqueueMailingListEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(true) }

      # As an admin
      And { unapproved_user.update_attributes(admin: true, moderator: false) }
      And { expect(Jobs::EnqueueMailingListEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(true) }

      # As an approved user
      And { unapproved_user.update_attributes(admin: false, moderator: false, approved: true ) }
      And { expect(Jobs::EnqueueMailingListEmails.new.target_user_ids.include?(unapproved_user.id)).to eq(true) }
    end

    context 'staged users' do
      let!(:staged_user) { Fabricate(:active_user, staged: true, last_emailed_at: 1.year.ago, last_seen_at: 1.year.ago) }

      it "doesn't return staged users" do
        expect(Jobs::EnqueueMailingListEmails.new.target_user_ids.include?(staged_user.id)).to eq(false)
      end
    end

    context "inactive user" do
      let!(:inactive_user) { Fabricate(:user, active: false) }

      it "doesn't return users who have been emailed recently" do
        expect(Jobs::EnqueueMailingListEmails.new.target_user_ids.include?(inactive_user.id)).to eq(false)
      end
    end

    context "suspended user" do
      let!(:suspended_user) { Fabricate(:user, suspended_till: 1.week.from_now, suspended_at: 1.day.ago) }

      it "doesn't return users who are suspended" do
        expect(Jobs::EnqueueMailingListEmails.new.target_user_ids.include?(suspended_user.id)).to eq(false)
      end
    end

    context 'users with mailing list mode on' do
      let!(:user) { Fabricate(:active_user) }

      it "returns the user if the frequency is set to daily" do
        user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 0)
        expect(Jobs::EnqueueMailingListEmails.new.target_user_ids).to eq([user.id])
      end

      it "does not return the user if the frequency is not set to daily" do
        user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 1)
        expect(Jobs::EnqueueMailingListEmails.new.target_user_ids).to_not eq([user.id])
      end
    end

  end

  describe '#execute' do

    let(:user) { Fabricate(:user) }

    context "mailing list emails are enabled" do
      before do
        Jobs::EnqueueMailingListEmails.any_instance.expects(:target_user_ids).returns([user.id])
      end

      it "enqueues the mailing list email job" do
        SiteSetting.stubs(:disable_digest_emails?).returns(false)
        Jobs.expects(:enqueue).with(:user_email, type: :mailing_list, user_id: user.id)
        Jobs::EnqueueMailingListEmails.new.execute({})
      end
    end

    context "mailing list emails are disabled" do
      before do
        Jobs::EnqueueMailingListEmails.any_instance.expects(:target_user_ids).never
      end

      it "does not enqueue the digest email job" do
        SiteSetting.disable_mailing_list_mode = true
        Jobs.expects(:enqueue).with(:user_email, type: :mailing_list, user_id: user.id).never
        Jobs::EnqueueMailingListEmails.new.execute({})
      end
    end

  end


end
