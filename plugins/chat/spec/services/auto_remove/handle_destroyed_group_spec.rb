# frozen_string_literal: true

RSpec.describe Chat::AutoRemove::HandleDestroyedGroup do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:destroyed_group_user_ids) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    let(:params) { { destroyed_group_user_ids: [admin_1.id, admin_2.id, user_1.id, user_2.id] } }
    fab!(:user_1) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:admin_1) { Fabricate(:admin) }
    fab!(:admin_2) { Fabricate(:admin) }

    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [admin_1, user_1]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:channel_2) { Fabricate(:chat_channel) }

    context "when chat is not enabled" do
      before { SiteSetting.chat_enabled = false }

      it { is_expected.to fail_a_policy(:chat_enabled) }
    end

    context "when chat is enabled" do
      before { SiteSetting.chat_enabled = true }

      context "if none of the group_user_ids users exist" do
        before { User.where(id: params[:destroyed_group_user_ids]).destroy_all }

        it "fails to find scoped_users model" do
          expect(result).to fail_to_find_a_model(:scoped_users)
        end
      end

      describe "step remove_users_outside_allowed_groups" do
        context "when chat_allowed_groups is empty" do
          before do
            SiteSetting.chat_allowed_groups = ""
            channel_1.add(user_1)
            channel_1.add(user_2)
            channel_2.add(user_1)
            channel_2.add(user_2)
            channel_1.add(admin_1)
            channel_1.add(admin_2)
          end

          it { is_expected.to run_successfully }

          it "removes the destroyed_group_user_ids from all public channels" do
            expect { result }.to change {
              Chat::UserChatChannelMembership.where(
                user: [user_1, user_2],
                chat_channel: [channel_1, channel_2],
              ).count
            }.to 0
          end

          it "does not remove admin users from public channels" do
            expect { result }.not_to change {
              Chat::UserChatChannelMembership.where(
                user: [admin_1, admin_2],
                chat_channel: [channel_1],
              ).count
            }
          end

          it "does not remove regular or admin users from direct message channels" do
            expect { result }.not_to change {
              Chat::UserChatChannelMembership.where(
                chat_channel: [dm_channel_1, dm_channel_2],
              ).count
            }
          end

          it "enqueues a job to kick each batch of users from the channel" do
            freeze_time
            result
            expect(
              job_enqueued?(
                job: Jobs::Chat::KickUsersFromChannel,
                at: 5.seconds.from_now,
                args: {
                  user_ids: [user_1.id, user_2.id],
                  channel_id: channel_1.id,
                },
              ),
            ).to eq(true)
            expect(
              job_enqueued?(
                job: Jobs::Chat::KickUsersFromChannel,
                at: 5.seconds.from_now,
                args: {
                  user_ids: [user_1.id, user_2.id],
                  channel_id: channel_2.id,
                },
              ),
            ).to eq(true)
          end

          it "logs a staff action" do
            result
            actions = UserHistory.where(custom_type: "chat_auto_remove_membership")
            expect(actions.count).to eq(2)
            expect(
              actions.exists?(
                details: "users_removed: 2\nchannel_id: #{channel_2.id}\nevent: destroyed_group",
                acting_user_id: Discourse.system_user.id,
                custom_type: "chat_auto_remove_membership",
              ),
            ).to eq(true)
            expect(
              actions.exists?(
                details: "users_removed: 2\nchannel_id: #{channel_1.id}\nevent: destroyed_group",
                acting_user_id: Discourse.system_user.id,
                custom_type: "chat_auto_remove_membership",
              ),
            ).to eq(true)
          end
        end

        context "when chat_allowed_groups includes all the users in public channels" do
          before do
            SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
            channel_1.add(user_1)
            channel_1.add(user_2)
            channel_2.add(user_1)
            channel_2.add(user_2)
            channel_1.add(admin_1)
            channel_1.add(admin_2)
          end

          it { is_expected.to run_successfully }

          it "does not remove any memberships" do
            expect { result }.not_to change { Chat::UserChatChannelMembership.count }
          end
        end

        context "when chat_allowed_groups includes everyone" do
          before do
            SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
            channel_1.add(user_1)
            channel_1.add(user_2)
            channel_2.add(user_1)
            channel_2.add(user_2)
            channel_1.add(admin_1)
            channel_1.add(admin_2)
          end

          it { is_expected.to fail_a_policy(:not_everyone_allowed) }

          it "does not remove any memberships" do
            expect { result }.not_to change { Chat::UserChatChannelMembership.count }
          end
        end
      end

      describe "step remove_users_without_channel_permission" do
        before do
          channel_1.add(user_1)
          channel_1.add(user_2)
          channel_2.add(user_1)
          channel_2.add(user_2)
          channel_1.add(admin_1)
          channel_1.add(admin_2)
        end

        context "when channel category not read_restricted with no category_groups" do
          before do
            channel_1.chatable.update!(read_restricted: false)
            channel_1.chatable.category_groups.destroy_all
          end

          it "does not remove any memberships" do
            expect { result }.not_to change { Chat::UserChatChannelMembership.count }
          end
        end

        context "when category channel not read_restricted with no full/create_post permission groups" do
          before do
            channel_1.chatable.update!(read_restricted: false)
            CategoryGroup.create!(
              category: channel_1.chatable,
              group_id: Group::AUTO_GROUPS[:everyone],
              permission_type: CategoryGroup.permission_types[:readonly],
            )
            CategoryGroup.create!(
              category: channel_1.chatable,
              group_id: Group::AUTO_GROUPS[:trust_level_1],
              permission_type: CategoryGroup.permission_types[:readonly],
            )
          end

          it { is_expected.to run_successfully }

          it "removes the destroyed_group_user_ids from the channel" do
            expect { result }.to change {
              Chat::UserChatChannelMembership.where(
                user: [user_1, user_2],
                chat_channel: [channel_1],
              ).count
            }.to 0
          end

          it "does not remove any admin destroyed_group_user_ids from the channel" do
            expect { result }.not_to change {
              Chat::UserChatChannelMembership.where(
                user: [admin_1, admin_2],
                chat_channel: [channel_1],
              ).count
            }
          end
        end

        context "when category channel not read_restricted with at least one full/create_post permission group" do
          before do
            channel_1.chatable.update!(read_restricted: false)
            CategoryGroup.create!(
              category: channel_1.chatable,
              group_id: Group::AUTO_GROUPS[:everyone],
              permission_type: CategoryGroup.permission_types[:readonly],
            )
            CategoryGroup.create!(
              category: channel_1.chatable,
              group_id: Group::AUTO_GROUPS[:trust_level_2],
              permission_type: CategoryGroup.permission_types[:create_post],
            )
          end

          context "when one of the users is not in any of the groups" do
            before { user_2.change_trust_level!(TrustLevel[3]) }

            it { is_expected.to run_successfully }

            it "removes the destroyed_group_user_ids from the channel" do
              expect { result }.to change {
                Chat::UserChatChannelMembership.where(
                  user: [user_1, user_2],
                  chat_channel: [channel_1],
                ).count
              }.to 1
            end
          end
        end
      end
    end
  end
end
