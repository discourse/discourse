# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewableUser, type: :model do

  fab!(:moderator) { Fabricate(:moderator) }
  let(:user) do
    user = Fabricate(:user)
    user.activate
    user
  end
  fab!(:admin) { Fabricate(:admin) }

  context "actions_for" do
    fab!(:reviewable) { Fabricate(:reviewable) }
    it "returns correct actions in the pending state" do
      actions = reviewable.actions_for(Guardian.new(moderator))
      expect(actions.has?(:approve_user)).to eq(true)
      expect(actions.has?(:reject_user_delete)).to eq(true)
      expect(actions.has?(:reject_user_block)).to eq(true)
    end

    it "doesn't return anything in the approved state" do
      reviewable.status = Reviewable.statuses[:approved]
      actions = reviewable.actions_for(Guardian.new(moderator))
      expect(actions.has?(:approve_user)).to eq(false)
      expect(actions.has?(:reject_user_delete)).to eq(false)
    end
  end

  context "#update_fields" do
    fab!(:moderator) { Fabricate(:moderator) }
    fab!(:reviewable) { Fabricate(:reviewable) }

    it "doesn't raise errors with an empty update" do
      expect(reviewable.update_fields(nil, moderator)).to eq(true)
      expect(reviewable.update_fields({}, moderator)).to eq(true)
    end
  end

  context "when a user is deleted" do
    it "should reject the reviewable" do
      SiteSetting.must_approve_users = true
      Jobs::CreateUserReviewable.new.execute(user_id: user.id)
      reviewable = Reviewable.find_by(target: user)
      expect(reviewable.pending?).to eq(true)

      UserDestroyer.new(Discourse.system_user).destroy(user)
      expect(reviewable.reload.rejected?).to eq(true)
    end
  end

  context "perform" do
    fab!(:reviewable) { Fabricate(:reviewable) }
    context "approve" do
      it "allows us to approve a user" do
        result = reviewable.perform(moderator, :approve_user)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.approved?).to eq(true)
        expect(reviewable.target.approved?).to eq(true)
        expect(reviewable.target.approved_by_id).to eq(moderator.id)
        expect(reviewable.target.approved_at).to be_present
        expect(reviewable.version > 0).to eq(true)
      end

      it "allows us to reject a user" do
        result = reviewable.perform(moderator, :reject_user_delete)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_blank
      end

      it "allows us to reject and block a user" do
        email = reviewable.target.email
        ip = reviewable.target.ip_address

        result = reviewable.perform(moderator, :reject_user_block)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_blank

        expect(ScreenedEmail.should_block?(email)).to eq(true)
        expect(ScreenedIpAddress.should_block?(ip)).to eq(true)
      end

      it "allows us to reject a user who has posts" do
        Fabricate(:post, user: reviewable.target)
        result = reviewable.perform(moderator, :reject_user_delete)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_present
        expect(reviewable.target.approved).to eq(false)
      end

      it "allows us to reject a user who has been deleted" do
        reviewable.target.destroy!
        reviewable.reload
        result = reviewable.perform(moderator, :reject_user_delete)
        expect(result.success?).to eq(true)
        expect(reviewable.rejected?).to eq(true)
        expect(reviewable.target).to be_blank
      end
    end
  end

  describe "changing must_approve_users" do
    it "will approve any existing users" do
      user = Fabricate(:user)
      expect(user).not_to be_approved
      SiteSetting.must_approve_users = true
      expect(user.reload).to be_approved
    end
  end

  describe 'when must_approve_users is true' do
    before do
      SiteSetting.must_approve_users = true
      Jobs.run_immediately!
    end

    it "creates the ReviewableUser for a user, with moderator access" do
      reviewable = ReviewableUser.find_by(target: user)
      expect(reviewable).to be_present
      expect(reviewable.reviewable_by_moderator).to eq(true)
    end

    context "email jobs" do
      let(:reviewable) { ReviewableUser.find_by(target: user) }
      before do
        reviewable

        # We can ignore these notifications for the purpose of this test
        Jobs.stubs(:enqueue).with(:notify_reviewable, has_key(:reviewable_id))
      end

      after do
        ReviewableUser.find_by(target: user).perform(admin, :approve_user)
      end

      it "enqueues a 'signup after approval' email if must_approve_users is true" do
        Jobs.expects(:enqueue).with(
          :critical_user_email, has_entries(type: :signup_after_approval)
        )
      end

      it "doesn't enqueue a 'signup after approval' email if must_approve_users is false" do
        SiteSetting.must_approve_users = false
        Jobs.expects(:enqueue).with(
          :critical_user_email, has_entries(type: :signup_after_approval)
        ).never
      end
    end

    it 'triggers a extensibility event' do
      user && admin # bypass the user_created event
      event = DiscourseEvent.track_events {
        ReviewableUser.find_by(target: user).perform(admin, :approve_user)
      }.first

      expect(event[:event_name]).to eq(:user_approved)
      expect(event[:params].first).to eq(user)
    end

    it 'triggers a extensibility event' do
      user && admin # bypass the user_created event
      event = DiscourseEvent.track_events {
        ReviewableUser.find_by(target: user).perform(admin, :approve_user)
      }.first

      expect(event[:event_name]).to eq(:user_approved)
      expect(event[:params].first).to eq(user)
    end
  end

end
