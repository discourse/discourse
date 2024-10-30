# frozen_string_literal: true

RSpec.describe Chat::LeaveChannel do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:channel_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:current_user) { Fabricate(:user) }

    let(:guardian) { Guardian.new(current_user) }
    let(:channel_id) { channel_1.id }
    let(:params) { { channel_id: } }
    let(:dependencies) { { guardian: } }

    before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone] }

    context "when all steps pass" do
      context "when category channel" do
        context "with existing membership" do
          before do
            channel_1.add(current_user)
            Chat::Channel.ensure_consistency!
          end

          it { is_expected.to run_successfully }

          it "unfollows the channel" do
            membership = channel_1.membership_for(current_user)

            expect { result }.to change { membership.reload.following }.from(true).to(false)
          end

          it "recomputes user count" do
            expect { result }.to change { channel_1.reload.user_count }.from(1).to(0)
          end
        end

        context "with no existing membership" do
          it { is_expected.to run_successfully }

          it "does nothing" do
            expect { result }.to_not change { Chat::UserChatChannelMembership }
          end
        end
      end

      context "when group channel" do
        context "with existing membership" do
          fab!(:channel_1) do
            Fabricate(:direct_message_channel, group: true, users: [current_user, Fabricate(:user)])
          end

          before { Chat::Channel.ensure_consistency! }

          it { is_expected.to run_successfully }

          it "leaves the channel" do
            membership = channel_1.membership_for(current_user)

            result

            expect(Chat::UserChatChannelMembership.exists?(membership.id)).to eq(false)
            expect(
              channel_1.chatable.direct_message_users.where(user_id: current_user.id).exists?,
            ).to eq(false)
          end

          it "recomputes user count" do
            expect { result }.to change { channel_1.reload.user_count }.from(2).to(1)
          end
        end

        context "with no existing membership" do
          it { is_expected.to run_successfully }

          it "does nothing" do
            expect { result }.to_not change { Chat::UserChatChannelMembership }
          end
        end
      end

      context "when direct channel" do
        context "with existing membership" do
          fab!(:channel_1) do
            Fabricate(:direct_message_channel, users: [current_user, Fabricate(:user)])
          end

          before { Chat::Channel.ensure_consistency! }

          it { is_expected.to run_successfully }

          it "unfollows the channel" do
            membership = channel_1.membership_for(current_user)

            expect { result }.to change { membership.reload.following }.from(true).to(false)
            expect(
              channel_1.chatable.direct_message_users.where(user_id: current_user.id).exists?,
            ).to eq(true)
          end

          it "recomputes user count" do
            expect { result }.to_not change { channel_1.reload.user_count }
          end
        end

        context "with no existing membership" do
          it { is_expected.to run_successfully }

          it "does nothing" do
            expect { result }.to_not change { Chat::UserChatChannelMembership }
          end
        end
      end
    end

    context "when channel is not found" do
      before { params[:channel_id] = -999 }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end
  end
end
