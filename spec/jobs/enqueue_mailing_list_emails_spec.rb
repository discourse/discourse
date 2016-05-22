require 'rails_helper'
require_dependency 'jobs/base'

describe Jobs::EnqueueMailingListEmails do

  describe '#target_users' do

    context 'unapproved users' do
      Given!(:unapproved_user) { Fabricate(:active_user, approved: false, first_seen_at: 24.hours.ago) }
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
      let(:user) { Fabricate(:active_user, first_seen_at: 24.hours.ago) }
      let(:user_option) { user.user_option }
      subject { Jobs::EnqueueMailingListEmails.new.target_user_ids }
      before do
        user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 0)
      end

      it "returns a user whose first_seen_at matches the current hour" do
        expect(subject).to include user.id
      end

      it "returns a user seen multiple days ago" do
        user.update(first_seen_at: 72.hours.ago)
        expect(subject).to include user.id
      end

      it "doesn't return a user who has never been seen" do
        user.update(first_seen_at: nil)
        expect(subject).to_not include user.id
      end

      it "doesn't return users with mailing list mode off" do
        user_option.update(mailing_list_mode: false)
        expect(subject).to_not include user.id
      end

      it "doesn't return users with mailing list mode set to 'individual'" do
        user_option.update(mailing_list_mode_frequency: 1)
        expect(subject).to_not include user.id
      end

      it "doesn't return a user who has received the mailing list summary earlier" do
        user.update(first_seen_at: 5.hours.ago)
        expect(subject).to_not include user.id
      end

      it "doesn't return a user who was first seen today" do
        user.update(first_seen_at: 2.minutes.ago)
        expect(subject).to_not include user.id
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
        Jobs.expects(:enqueue).with(:user_email, type: :mailing_list, user_id: user.id)
        Jobs::EnqueueMailingListEmails.new.execute({})
      end
    end

    context "mailing list emails are disabled" do
      before do
        Jobs::EnqueueMailingListEmails.any_instance.expects(:target_user_ids).never
      end

      it "does not enqueue the mailing list email job" do
        SiteSetting.disable_mailing_list_mode = true
        Jobs.expects(:enqueue).with(:user_email, type: :mailing_list, user_id: user.id).never
        Jobs::EnqueueMailingListEmails.new.execute({})
      end
    end

  end


end
