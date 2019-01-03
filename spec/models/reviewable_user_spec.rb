require 'rails_helper'

RSpec.describe ReviewableUser, type: :model do

  let(:moderator) { Fabricate(:moderator) }
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  context "actions_for" do
    let(:reviewable) { Fabricate(:reviewable) }
    it "returns approve/disapprove in the pending state" do
      actions = reviewable.actions_for(Guardian.new(moderator))
      expect(actions.has?(:approve)).to eq(true)
      expect(actions.has?(:reject)).to eq(true)
    end

    it "doesn't return anything in the approved state" do
      reviewable.status = Reviewable.statuses[:approved]
      actions = reviewable.actions_for(Guardian.new(moderator))
      expect(actions.has?(:approve)).to eq(false)
      expect(actions.has?(:reject)).to eq(false)
    end
  end

  context "#update_fields" do
    let(:moderator) { Fabricate(:moderator) }
    let(:reviewable) { Fabricate(:reviewable) }

    it "doesn't raise errors with an empty update" do
      expect(reviewable.update_fields(nil, moderator)).to eq(true)
      expect(reviewable.update_fields({}, moderator)).to eq(true)
    end
  end

  context "perform" do
    let(:reviewable) { Fabricate(:reviewable) }
    context "approve" do
      it "allows us to approve a user" do
        result = reviewable.perform(moderator, :approve)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.approved?).to eq(true)
        expect(reviewable.target.approved?).to eq(true)
        expect(reviewable.target.approved_by_id).to eq(moderator.id)
        expect(reviewable.target.approved_at).to be_present
        expect(reviewable.version > 0).to eq(true)
      end

      it "allows us to reject a user" do
        result = reviewable.perform(moderator, :reject)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_blank
      end
    end
  end

  describe 'when must_approve_users is true' do
    before do
      SiteSetting.must_approve_users = true
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
        ReviewableUser.find_by(target: user).perform(admin, :approve)
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
        ReviewableUser.find_by(target: user).perform(admin, :approve)
      }.first

      expect(event[:event_name]).to eq(:user_approved)
      expect(event[:params].first).to eq(user)
    end

    it 'triggers a extensibility event' do
      user && admin # bypass the user_created event
      event = DiscourseEvent.track_events {
        ReviewableUser.find_by(target: user).perform(admin, :approve)
      }.first

      expect(event[:event_name]).to eq(:user_approved)
      expect(event[:params].first).to eq(user)
    end
  end

end
