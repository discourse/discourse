# frozen_string_literal: true

RSpec.describe Chat::MarkPinsAsRead do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:channel_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:chatters, :group)
    fab!(:user) { Fabricate(:user, group_ids: [chatters.id]) }
    fab!(:channel, :chat_channel)
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user)
    end

    let(:guardian) { Guardian.new(user) }
    let(:params) { { channel_id: channel.id } }
    let(:dependencies) { { guardian: } }

    before { SiteSetting.chat_allowed_groups = chatters }

    context "when params are not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when channel is not found" do
      let(:params) { { channel_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when membership is not found" do
      before { membership.destroy! }

      it { is_expected.to fail_to_find_a_model(:membership) }
    end

    context "when user cannot access channel" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }

      before { channel.update!(chatable: private_category) }

      it { is_expected.to fail_a_policy(:can_access_channel) }
    end

    context "when all conditions are met" do
      it { is_expected.to run_successfully }

      it "updates last_viewed_pins_at timestamp" do
        freeze_time
        expect { result }.to change { membership.reload.last_viewed_pins_at }.to(Time.zone.now)
      end
    end
  end
end
