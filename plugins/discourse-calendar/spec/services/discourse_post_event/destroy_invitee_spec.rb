# frozen_string_literal: true

RSpec.describe(DiscoursePostEvent::DestroyInvitee) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
    it { is_expected.to validate_presence_of(:id) }
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

    let(:params) { { post_id: event.id, id: invitee.id } }
    let(:dependencies) { { guardian: invitee_user.guardian } }

    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    context "when contract is invalid" do
      let(:params) { { post_id: nil, id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when event does not exist" do
      let(:params) { { post_id: -1, id: invitee.id } }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when invitee does not exist" do
      let(:params) { { post_id: event.id, id: -1 } }

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

      let(:params) { { post_id: private_event.id, id: private_invitee.id } }

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

      let(:params) { { post_id: closed_event.id, id: closed_invitee.id } }

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

      let(:params) { { post_id: expired_event.id, id: expired_invitee.id } }

      it { is_expected.to fail_a_policy(:can_update_attendance) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "destroys the invitee" do
        expect { result }.to change { DiscoursePostEvent::Invitee.count }.by(-1)
        expect(DiscoursePostEvent::Invitee.exists?(invitee.id)).to eq(false)
      end
    end

    context "when staff destroys another user's invitee" do
      let(:dependencies) { { guardian: admin.guardian } }

      it { is_expected.to run_successfully }

      it "destroys the invitee" do
        expect { result }.to change { DiscoursePostEvent::Invitee.count }.by(-1)
      end
    end
  end
end
