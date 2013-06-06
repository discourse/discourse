require 'spec_helper'
require 'jobs'

describe Jobs::EnqueueDigestEmails do


  describe '#target_users' do

    context 'disabled digests' do
      let!(:user_no_digests) { Fabricate(:user, email_digests: false, last_emailed_at: 8.days.ago, last_seen_at: 10.days.ago) }

      it "doesn't return users with email disabled" do
        Jobs::EnqueueDigestEmails.new.target_users.include?(user_no_digests).should be_false
      end
    end

    context 'unapproved users' do
      Given!(:unapproved_user) { Fabricate(:user, approved: false, last_emailed_at: 8.days.ago, last_seen_at: 10.days.ago) }
      When { SiteSetting.stubs(:must_approve_users?).returns(true) }
      Then { expect(Jobs::EnqueueDigestEmails.new.target_users.include?(unapproved_user)).to eq(false) }

      # As a moderator
      And { unapproved_user.update_column(:moderator, true) }
      And { expect(Jobs::EnqueueDigestEmails.new.target_users.include?(unapproved_user)).to eq(true) }

      # As an admin
      And { unapproved_user.update_attributes(admin: true, moderator: false) }
      And { expect(Jobs::EnqueueDigestEmails.new.target_users.include?(unapproved_user)).to eq(true) }

      # As an approved user
      And { unapproved_user.update_attributes(admin: false, moderator: false, approved: true ) }
      And { expect(Jobs::EnqueueDigestEmails.new.target_users.include?(unapproved_user)).to eq(true) }
    end

    context 'recently emailed' do
      let!(:user_emailed_recently) { Fabricate(:user, last_emailed_at: 6.days.ago) }

      it "doesn't return users who have been emailed recently" do
        Jobs::EnqueueDigestEmails.new.target_users.include?(user_emailed_recently).should be_false
      end
    end

    context 'visited the site today' do
      let!(:user_visited_today) { Fabricate(:user, last_seen_at: 6.days.ago) }

      it "doesn't return users who have been emailed recently" do
        Jobs::EnqueueDigestEmails.new.target_users.include?(user_visited_today).should be_false
      end
    end


    context 'regular users' do
      let!(:user) { Fabricate(:user) }

      it "returns the user" do
        Jobs::EnqueueDigestEmails.new.target_users.should == [user]
      end
    end

  end

  describe '#execute' do

    let(:user) { Fabricate(:user) }

    before do
      Jobs::EnqueueDigestEmails.any_instance.expects(:target_users).returns([user])
    end

    it "enqueues the digest email job" do
      Jobs.expects(:enqueue).with(:user_email, type: :digest, user_id: user.id)
      Jobs::EnqueueDigestEmails.new.execute({})
    end

  end


end

