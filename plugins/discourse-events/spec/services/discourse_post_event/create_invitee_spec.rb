# frozen_string_literal: true

RSpec.describe(DiscoursePostEvent::CreateInvitee) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:event_id) }
    it do
      is_expected.to validate_inclusion_of(:status).in_array(
        DiscoursePostEvent::Invitee.statuses.keys.map(&:to_s),
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: current_user) }
    fab!(:post) { Fabricate(:post, user: current_user, topic: topic) }
    fab!(:event) { Fabricate(:event, post: post) }

    let(:params) { { event_id: event.id, status: "going" } }
    let(:dependencies) { { guardian: current_user.guardian } }

    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    context "when contract is invalid" do
      let(:params) { { event_id: event.id, status: "invalid" } }

      it { is_expected.to fail_a_contract }
    end

    context "when event does not exist" do
      let(:params) { { event_id: -1, status: "going" } }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when user cannot see the event post" do
      fab!(:private_event)

      let(:params) { { event_id: private_event.id, status: "going" } }

      it { is_expected.to fail_a_policy(:can_see_event) }
    end

    context "when event is closed" do
      fab!(:closed_post) { Fabricate(:post, topic: topic) }
      fab!(:closed_event) { Fabricate(:event, post: closed_post, closed: true) }

      let(:params) { { event_id: closed_event.id, status: "going" } }

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

      let(:params) { { event_id: expired_event.id, status: "going" } }

      it { is_expected.to fail_a_policy(:can_update_attendance) }
    end

    context "when non-staff user tries to invite another user" do
      fab!(:other_user, :user)
      let(:params) { { event_id: event.id, status: "going", user_id: other_user.id } }

      it { is_expected.to fail_a_policy(:can_invite_user) }
    end

    context "when event is at max capacity" do
      fab!(:other_user, :user)
      fab!(:full_post) { Fabricate(:post, topic: topic) }
      fab!(:full_event) { Fabricate(:event, post: full_post, max_attendees: 1) }

      before do
        full_event.create_invitees(
          [{ user_id: other_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] }],
        )
      end

      let(:params) { { event_id: full_event.id, status: "going" } }

      it { is_expected.to fail_a_policy(:has_capacity) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates the invitee" do
        expect { result }.to change { DiscoursePostEvent::Invitee.count }.by(1)
        expect(result[:invitee]).to have_attributes(
          user_id: current_user.id,
          post_id: event.id,
          status: DiscoursePostEvent::Invitee.statuses[:going],
        )
      end
    end

    context "when staff invites another user" do
      fab!(:admin, :admin)
      fab!(:other_user, :user)

      let(:dependencies) { { guardian: admin.guardian } }
      let(:params) { { event_id: event.id, status: "interested", user_id: other_user.id } }

      it { is_expected.to run_successfully }

      it "creates the invitee for the other user" do
        expect { result }.to change { DiscoursePostEvent::Invitee.count }.by(1)
        expect(result[:invitee]).to have_attributes(
          user_id: other_user.id,
          status: DiscoursePostEvent::Invitee.statuses[:interested],
        )
      end
    end
  end
end
