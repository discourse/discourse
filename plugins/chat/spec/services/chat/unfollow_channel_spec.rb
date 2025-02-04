# frozen_string_literal: true

RSpec.describe Chat::UnfollowChannel do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new }

    it { is_expected.to validate_presence_of(:channel_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:current_user) { Fabricate(:user) }

    let(:params) { { channel_id: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { Guardian.new(current_user) }
    let(:channel_id) { channel_1.id }

    before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone] }

    context "when all steps pass" do
      context "with existing membership" do
        let(:membership) { channel_1.membership_for(current_user) }

        before { channel_1.add(current_user) }

        it { is_expected.to run_successfully }

        it "unfollows the channel" do
          expect { result }.to change { membership.reload.following }.from(true).to(false)
        end
      end

      context "with no existing membership" do
        it { is_expected.to run_successfully }

        it "does nothing" do
          expect { result }.to_not change { Chat::UserChatChannelMembership }
        end
      end
    end

    context "when channel is not found" do
      let(:channel_id) { -999 }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end
  end
end
