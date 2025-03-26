# frozen_string_literal: true

RSpec.describe Chat::RemoveUserFromChannel do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :user_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user) { Fabricate(:admin) }
    fab!(:user)
    fab!(:channel) { Fabricate(:chat_channel) }

    let(:guardian) { Guardian.new(acting_user) }
    let(:params) { { channel_id: channel.id, user_id: user.id } }
    let(:dependencies) { { guardian: } }

    context "when all steps pass" do
      context "when category channel" do
        context "with existing membership" do
          before do
            channel.add(user)
            channel.add(acting_user)
            Chat::Channel.ensure_consistency!
          end

          it { is_expected.to run_successfully }

          it "unfollows the channel" do
            membership = channel.membership_for(user)

            expect { result }.to change { membership.reload.following }.from(true).to(false)
          end

          it "recomputes user count" do
            expect { result }.to change { channel.reload.user_count }.from(2).to(1)
          end
        end

        context "with no existing membership" do
          it { is_expected.to run_successfully }

          it "does nothing" do
            expect { result }.to_not change { Chat::UserChatChannelMembership.count }
          end
        end
      end

      context "when group channel" do
        context "with existing membership" do
          fab!(:channel) do
            Fabricate(:direct_message_channel, group: true, users: [acting_user, user])
          end

          before { Chat::Channel.ensure_consistency! }

          it { is_expected.to run_successfully }

          it "leaves the channel" do
            membership = channel.membership_for(user)

            result

            expect(Chat::UserChatChannelMembership.exists?(membership.id)).to eq(false)
            expect(channel.chatable.direct_message_users.where(user_id: user.id).exists?).to eq(
              false,
            )
          end

          it "recomputes user count" do
            expect { result }.to change { channel.reload.user_count }.from(2).to(1)
          end
        end

        context "with no existing membership" do
          it { is_expected.to run_successfully }

          it "does nothing" do
            expect { result }.to_not change { Chat::UserChatChannelMembership.count }
          end
        end
      end

      context "when channel is a one-on-one DM" do
        context "with existing membership" do
          fab!(:channel) { Fabricate(:direct_message_channel, users: [acting_user, user]) }

          it { is_expected.to fail_a_policy(:can_remove_users_from_channel) }
        end
      end
    end

    context "when target user is not found" do
      before do
        params[:user_id] = 31_337
        params[:channel_id] = channel.id
      end

      it { is_expected.to fail_to_find_a_model(:target_user) }
    end

    context "when channel is not found" do
      before do
        params[:user_id] = user.id
        params[:channel_id] = -999
      end

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when user is not an admin" do
      fab!(:acting_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:can_remove_users_from_channel) }
    end
  end
end
