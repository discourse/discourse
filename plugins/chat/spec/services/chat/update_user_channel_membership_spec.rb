# frozen_string_literal: true

RSpec.describe Chat::UpdateUserChannelMembership do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:channel_id) }
    it { is_expected.not_to allow_value(nil).for(:pinned) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)
    fab!(:channel, :category_channel)
    fab!(:membership) do
      Fabricate(
        :user_chat_channel_membership,
        user: current_user,
        chat_channel: channel,
        pinned: false,
      )
    end

    let(:params) { { channel_id: channel.id, pinned: true } }
    let(:dependencies) { { guardian: current_user.guardian } }

    context "when contract is invalid" do
      let(:params) { { pinned: true } }

      it { is_expected.to fail_a_contract }
    end

    context "when channel is not found" do
      let(:params) { { channel_id: -999, pinned: true } }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when membership is not found" do
      before { membership.destroy! }

      it { is_expected.to fail_to_find_a_model(:membership) }
    end

    context "when user cannot access channel" do
      fab!(:private_channel, :private_category_channel)
      fab!(:private_membership) do
        Fabricate(
          :user_chat_channel_membership,
          user: current_user,
          chat_channel: private_channel,
          pinned: false,
        )
      end
      let(:params) { { channel_id: private_channel.id, pinned: true } }

      it { is_expected.to fail_a_policy(:can_access_channel) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "updates the pinned status" do
        expect { result }.to change { membership.reload.pinned }.from(false).to(true)
      end
    end
  end
end
