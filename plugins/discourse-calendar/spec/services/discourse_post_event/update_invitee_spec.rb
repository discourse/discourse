# frozen_string_literal: true

RSpec.describe(DiscoursePostEvent::UpdateInvitee) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_presence_of(:invitee_id) }
    it do
      is_expected.to validate_inclusion_of(:status).in_array(
        DiscoursePostEvent::Invitee.statuses.keys.map(&:to_s),
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin, :admin)
    fab!(:topic) { Fabricate(:topic, user: admin) }
    fab!(:post) { Fabricate(:post, user: admin, topic: topic) }
    fab!(:event) { Fabricate(:event, post: post) }
    fab!(:invitee_user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:invitee) do
      event.create_invitees(
        [{ user_id: invitee_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] }],
      )
      event.invitees.find_by(user_id: invitee_user.id)
    end

    let(:params) { { event_id: event.id, invitee_id: invitee.id, status: "interested" } }
    let(:dependencies) { { guardian: invitee_user.guardian } }

    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    context "when contract is invalid" do
      let(:params) { { event_id: event.id, invitee_id: invitee.id, status: "invalid" } }

      it { is_expected.to fail_a_contract }
    end

    context "when invitee does not exist" do
      let(:params) { { event_id: event.id, invitee_id: -1, status: "interested" } }

      it { is_expected.to fail_to_find_a_model(:invitee) }
    end

    context "when user cannot act on invitee" do
      fab!(:other_user, :user)
      let(:dependencies) { { guardian: other_user.guardian } }

      it { is_expected.to fail_a_policy(:can_act_on_invitee) }
    end

    context "when user cannot see the event post" do
      fab!(:private_event)
      fab!(:private_invitee) do
        private_event.create_invitees(
          [{ user_id: invitee_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] }],
        )
        private_event.invitees.find_by(user_id: invitee_user.id)
      end

      let(:params) do
        { event_id: private_event.id, invitee_id: private_invitee.id, status: "interested" }
      end

      it { is_expected.to fail_a_policy(:can_see_event) }
    end

    context "when event is closed" do
      fab!(:closed_post) { Fabricate(:post, topic: topic) }
      fab!(:closed_event) { Fabricate(:event, post: closed_post, closed: true) }
      fab!(:closed_invitee) do
        closed_event.create_invitees(
          [{ user_id: invitee_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] }],
        )
        closed_event.invitees.find_by(user_id: invitee_user.id)
      end

      let(:params) do
        { event_id: closed_event.id, invitee_id: closed_invitee.id, status: "not_going" }
      end

      it { is_expected.to fail_a_policy(:can_update_attendance) }
    end

    context "when event is expired" do
      fab!(:expired_post) { Fabricate(:post, topic: topic) }
      fab!(:expired_event) do
        Fabricate(
          :event,
          post: expired_post,
          original_starts_at: 2.days.ago,
          original_ends_at: 1.day.ago,
        )
      end
      fab!(:expired_invitee) do
        expired_event.create_invitees(
          [{ user_id: invitee_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] }],
        )
        expired_event.invitees.find_by(user_id: invitee_user.id)
      end

      let(:params) do
        { event_id: expired_event.id, invitee_id: expired_invitee.id, status: "not_going" }
      end

      it { is_expected.to fail_a_policy(:can_update_attendance) }
    end

    context "when event is at max capacity" do
      fab!(:other_user, :user)
      fab!(:full_post) { Fabricate(:post, topic: topic) }
      fab!(:full_event) { Fabricate(:event, post: full_post, max_attendees: 1) }
      fab!(:going_invitee) do
        full_event.create_invitees(
          [{ user_id: other_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] }],
        )
        full_event.invitees.find_by(user_id: other_user.id)
      end
      fab!(:interested_invitee) do
        full_event.create_invitees(
          [{ user_id: invitee_user.id, status: DiscoursePostEvent::Invitee.statuses[:interested] }],
        )
        full_event.invitees.find_by(user_id: invitee_user.id)
      end

      let(:params) do
        { event_id: full_event.id, invitee_id: interested_invitee.id, status: "going" }
      end

      it { is_expected.to fail_a_policy(:has_capacity) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "updates the invitee status" do
        expect { result }.to change { invitee.reload.status }.from(
          DiscoursePostEvent::Invitee.statuses[:going],
        ).to(DiscoursePostEvent::Invitee.statuses[:interested])
      end
    end
  end
end
