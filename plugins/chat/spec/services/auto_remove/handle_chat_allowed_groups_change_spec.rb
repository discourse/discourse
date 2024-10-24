# frozen_string_literal: true

RSpec.describe Chat::AutoRemove::HandleChatAllowedGroupsChange do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    let(:params) { { new_allowed_groups: } }
    fab!(:user_1) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:admin_1) { Fabricate(:admin) }
    fab!(:admin_2) { Fabricate(:admin) }

    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [admin_1, user_1]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

    fab!(:public_channel_1) { Fabricate(:chat_channel) }
    fab!(:public_channel_2) { Fabricate(:chat_channel) }

    context "when chat is not enabled" do
      let(:new_allowed_groups) { "1|2" }

      before { SiteSetting.chat_enabled = false }

      it { is_expected.to fail_a_policy(:chat_enabled) }
    end

    context "when chat is enabled" do
      before { SiteSetting.chat_enabled = true }

      context "when new_allowed_groups is empty" do
        let(:new_allowed_groups) { "" }

        before do
          public_channel_1.add(user_1)
          public_channel_1.add(user_2)
          public_channel_2.add(user_1)
          public_channel_2.add(user_2)
          public_channel_1.add(admin_1)
          public_channel_1.add(admin_2)
          freeze_time
        end

        it "sets the service result as successful" do
          expect(result).to be_a_success
        end

        it "removes users from all public channels" do
          expect { result }.to change {
            Chat::UserChatChannelMembership.where(
              user: [user_1, user_2],
              chat_channel: [public_channel_1, public_channel_2],
            ).count
          }.to 0
        end

        it "does not remove admin users from public channels" do
          expect { result }.not_to change {
            Chat::UserChatChannelMembership.where(
              user: [admin_1, admin_2],
              chat_channel: [public_channel_1],
            ).count
          }
        end

        it "does not remove users from direct message channels" do
          expect { result }.not_to change {
            Chat::UserChatChannelMembership.where(chat_channel: [dm_channel_1, dm_channel_2]).count
          }
        end

        it "enqueues a job to kick each batch of users from the channel" do
          result
          expect(
            job_enqueued?(
              job: Jobs::Chat::KickUsersFromChannel,
              at: 5.seconds.from_now,
              args: {
                user_ids: [user_1.id, user_2.id],
                channel_id: public_channel_1.id,
              },
            ),
          ).to eq(true)
          expect(
            job_enqueued?(
              job: Jobs::Chat::KickUsersFromChannel,
              at: 5.seconds.from_now,
              args: {
                user_ids: [user_1.id, user_2.id],
                channel_id: public_channel_2.id,
              },
            ),
          ).to eq(true)
        end

        it "logs a staff action" do
          result

          changes =
            UserHistory
              .where(custom_type: "chat_auto_remove_membership")
              .all
              .map { |uh| uh.slice(:details, :acting_user_id) }

          expect(changes).to match_array(
            [
              {
                details:
                  "users_removed: 2\nchannel_id: #{public_channel_1.id}\nevent: chat_allowed_groups_changed",
                acting_user_id: Discourse.system_user.id,
              },
              {
                details:
                  "users_removed: 2\nchannel_id: #{public_channel_2.id}\nevent: chat_allowed_groups_changed",
                acting_user_id: Discourse.system_user.id,
              },
            ],
          )
        end
      end

      context "when new_allowed_groups includes all the users in public channels" do
        let(:new_allowed_groups) { Group::AUTO_GROUPS[:trust_level_1] }

        before do
          public_channel_1.add(user_1)
          public_channel_2.add(user_1)
        end

        it "does nothing" do
          expect { result }.not_to change { Chat::UserChatChannelMembership.count }
          expect(result).to fail_to_find_a_model(:users)
        end
      end

      context "when new_allowed_groups includes everyone" do
        let(:new_allowed_groups) { Group::AUTO_GROUPS[:everyone] }

        it { is_expected.to fail_a_policy(:not_everyone_allowed) }

        it "does nothing" do
          expect { result }.not_to change { Chat::UserChatChannelMembership.count }
        end
      end

      context "when some users are not in any of the new allowed groups" do
        let(:new_allowed_groups) { Group::AUTO_GROUPS[:trust_level_4] }

        before do
          public_channel_1.add(user_1)
          public_channel_1.add(user_2)
          public_channel_2.add(user_1)
          public_channel_2.add(user_2)
          user_1.change_trust_level!(TrustLevel[2])
          user_2.change_trust_level!(TrustLevel[4])
        end

        it "removes them from public channels" do
          expect { result }.to change {
            Chat::UserChatChannelMembership.where(
              chat_channel: [public_channel_1, public_channel_2],
            ).count
          }.by(-2)
        end

        it "does not remove them from direct message channels" do
          expect { result }.not_to change {
            Chat::UserChatChannelMembership.where(chat_channel: [dm_channel_2]).count
          }
        end
      end
    end
  end
end
