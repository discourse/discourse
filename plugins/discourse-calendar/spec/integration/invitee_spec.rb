# frozen_string_literal: true

describe DiscoursePostEvent::Invitee do
  before do
    freeze_time
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:user) { Fabricate(:user, admin: true) }
  let(:user_1) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:post1) { Fabricate(:post, topic: topic) }
  let(:post_event) { Fabricate(:event, post: post1) }

  context "when a user is destroyed" do
    context "when the user is an invitee to an event" do
      before { post_event.create_invitees([{ user_id: user_1.id, status: nil }]) }

      it "destroys the invitee" do
        expect(post_event.invitees.first.user.id).to eq(user_1.id)

        UserDestroyer.new(user_1).destroy(user_1)

        expect(post_event.invitees).to be_empty
      end
    end
  end

  describe "default scope filtering" do
    fab!(:regular_user, :user)
    fab!(:suspended_user) { Fabricate(:user, suspended_till: 1.year.from_now) }
    fab!(:silenced_user) { Fabricate(:user, silenced_till: 1.year.from_now) }
    fab!(:staged_user) { Fabricate(:user, staged: true) }

    before do
      post_event.create_invitees(
        [
          { user_id: regular_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] },
          { user_id: suspended_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] },
          { user_id: silenced_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] },
          { user_id: staged_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] },
        ],
      )
    end

    it "excludes suspended users from invitees" do
      expect(post_event.invitees.map(&:user_id)).not_to include(suspended_user.id)
    end

    it "excludes silenced users from invitees" do
      expect(post_event.invitees.map(&:user_id)).not_to include(silenced_user.id)
    end

    it "excludes staged users from invitees" do
      expect(post_event.invitees.map(&:user_id)).not_to include(staged_user.id)
    end

    it "includes regular users in invitees" do
      expect(post_event.invitees.map(&:user_id)).to include(regular_user.id)
    end

    it "includes users whose suspension has expired" do
      suspended_user.update!(suspended_till: 1.day.ago)
      expect(post_event.invitees.map(&:user_id)).to include(suspended_user.id)
    end

    it "includes users whose silence has expired" do
      silenced_user.update!(silenced_till: 1.day.ago)
      expect(post_event.invitees.map(&:user_id)).to include(silenced_user.id)
    end
  end
end
