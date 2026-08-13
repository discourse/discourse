# frozen_string_literal: true

RSpec.describe(DiscoursePostEvent::Invite) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:event_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin, :admin)
    fab!(:topic) { Fabricate(:topic, user: admin) }
    fab!(:post) { Fabricate(:post, user: admin, topic: topic) }
    fab!(:event) { Fabricate(:event, post: post) }
    fab!(:invited_user, :user)

    let(:params) { { event_id: event.id, invites: [invited_user.username] } }
    let(:dependencies) { { guardian: admin.guardian } }

    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    context "when contract is invalid" do
      let(:params) { { event_id: nil, invites: [invited_user.username] } }

      it { is_expected.to fail_a_contract }
    end

    context "when event does not exist" do
      let(:params) { { event_id: -1, invites: [invited_user.username] } }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when user cannot act on the event" do
      fab!(:other_user, :user)
      let(:dependencies) { { guardian: other_user.guardian } }

      it { is_expected.to fail_a_policy(:can_act_on_event) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "notifies the invited users" do
        expect { result }.to change { invited_user.notifications.count }.by(1)
      end
    end

    context "when invites is empty" do
      let(:params) { { event_id: event.id, invites: [] } }

      it { is_expected.to run_successfully }

      it "notifies no one" do
        expect { result }.not_to change { Notification.count }
      end
    end
  end
end
