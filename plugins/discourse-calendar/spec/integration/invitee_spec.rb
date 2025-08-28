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

  context "when updating an invitee's attendance" do
    let!(:invitee) do
      post_event.create_invitees([{ user_id: user_1.id, status: :going }])
      post_event.invitees.find_by(user_id: user_1.id)
    end

    context "when user updates their own attendance" do
      it "successfully updates the status" do
        expect {
          DiscoursePostEvent::UpdateInvitee.call(
            guardian: Guardian.new(user_1),
            params: {
              invitee_id: invitee.id,
              event_id: post1.id,
              status: "not_going",
            },
          )
        }.to change { invitee.reload.status }.to(DiscoursePostEvent::Invitee.statuses[:not_going])
      end

      it "triggers a discourse event" do
        events =
          DiscourseEvent.track_events do
            DiscoursePostEvent::UpdateInvitee.call(
              guardian: Guardian.new(user_1),
              params: {
                invitee_id: invitee.id,
                event_id: post1.id,
                status: "interested",
              },
            )
          end

        expect(events).to include(
          event_name: :discourse_calendar_post_event_invitee_status_changed,
          params: [invitee.reload],
        )
      end
    end

    context "when admin updates another user's attendance" do
      it "successfully updates the status" do
        expect {
          DiscoursePostEvent::UpdateInvitee.call(
            guardian: Guardian.new(user),
            params: {
              invitee_id: invitee.id,
              event_id: post1.id,
              status: "interested",
            },
          )
        }.to change { invitee.reload.status }.to(DiscoursePostEvent::Invitee.statuses[:interested])
      end
    end

    context "when event is at max capacity" do
      before do
        post_event.update!(max_attendees: 1)
        # Create another user who is already going
        other_user = Fabricate(:user)
        post_event.create_invitees(
          [{ user_id: other_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] }],
        )
        # Set current invitee to not_going initially
        invitee.update!(status: DiscoursePostEvent::Invitee.statuses[:not_going])
      end

      it "fails to update to going status" do
        result =
          DiscoursePostEvent::UpdateInvitee.call(
            guardian: Guardian.new(user_1),
            params: {
              invitee_id: invitee.id,
              event_id: post1.id,
              status: "going",
            },
          )

        expect(result).to be_failure
        expect(result).to fail_to_find_a_model(:updated_invitee)
        expect(invitee.reload.status).to eq(DiscoursePostEvent::Invitee.statuses[:not_going])
      end
    end

    context "when user cannot act on invitee" do
      let(:unauthorized_user) { Fabricate(:user) }

      it "fails the policy check" do
        result =
          DiscoursePostEvent::UpdateInvitee.call(
            guardian: Guardian.new(unauthorized_user),
            params: {
              invitee_id: invitee.id,
              event_id: post1.id,
              status: "going",
            },
          )

        expect(result).to be_failure
        expect(result).to fail_a_policy(:can_act_on_invitee)
      end
    end
  end
end
