# frozen_string_literal: true

RSpec.describe Chat::Service::AutoRemove::HandleDestroyedGroup do
  describe ".call" do
    let(:params) { { destroyed_group_user_ids: [admin_1.id, admin_2.id, user_1.id, user_2.id] } }
    subject(:result) { described_class.call(params) }

    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:admin_1) { Fabricate(:admin) }
    fab!(:admin_2) { Fabricate(:admin) }

    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [admin_1, user_1]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:channel_2) { Fabricate(:chat_channel) }

    before { SiteSetting.chat_enabled = true }

    it "fails model if none of the group_user_ids users exist" do
      User.where(id: params[:destroyed_group_user_ids]).destroy_all
      expect(result).to fail_to_find_a_model(:scoped_users)
    end

    describe "step remove_users_outside_allowed_groups" do
      context "when chat_allowed_groups is empty" do
        before { SiteSetting.chat_allowed_groups = "" }

        before do
          channel_1.add(user_1)
          channel_1.add(user_2)
          channel_2.add(user_1)
          channel_2.add(user_2)
          channel_1.add(admin_1)
          channel_1.add(admin_2)
        end

        it "removes the destroyed_group_user_ids from all public channels" do
          expect(result).to be_a_success
          expect(
            UserChatChannelMembership.where(
              user: [user_1, user_2],
              chat_channel: [channel_1, channel_2],
            ).count,
          ).to eq(0)
        end

        it "does not remove admin users from public channels" do
          expect(result).to be_a_success
          expect(
            UserChatChannelMembership.where(
              user: [admin_1, admin_2],
              chat_channel: [channel_1],
            ).count,
          ).to eq(2)
        end

        it "does not remove regular or admin users from direct message channels" do
          expect(result).to be_a_success
          expect(
            UserChatChannelMembership.where(
              user: [admin_1, user_1],
              chat_channel: [dm_channel_1],
            ).count,
          ).to eq(2)
          expect(
            UserChatChannelMembership.where(
              user: [user_1, user_2],
              chat_channel: [dm_channel_2],
            ).count,
          ).to eq(2)
        end

        it "enqueues a job to kick each batch of users from the channel" do
          freeze_time
          expect(result).to be_a_success
          expect(
            job_enqueued?(
              job: :kick_users_from_channel,
              at: 5.seconds.from_now,
              args: {
                user_ids: [user_1.id, user_2.id],
                channel_id: channel_1.id,
              },
            ),
          ).to eq(true)
          expect(
            job_enqueued?(
              job: :kick_users_from_channel,
              at: 5.seconds.from_now,
              args: {
                user_ids: [user_1.id, user_2.id],
                channel_id: channel_2.id,
              },
            ),
          ).to eq(true)
        end

        it "logs a staff action" do
          expect(result).to be_a_success
          action = UserHistory.last
          expect(action.details).to eq(
            "users_removed: 2\nchannel_id: #{channel_2.id}\nevent: destroyed_group",
          )
          expect(action.acting_user_id).to eq(Discourse.system_user.id)
          expect(action.custom_type).to eq("chat_auto_remove_membership")
        end
      end

      context "when chat_allowed_groups includes all the users in public channels" do
        before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_1] }

        before do
          channel_1.add(user_1)
          channel_1.add(user_2)
          channel_2.add(user_1)
          channel_2.add(user_2)
          channel_1.add(admin_1)
          channel_1.add(admin_2)
          Group.refresh_automatic_groups!
        end

        it "does nothing" do
          expect { result }.not_to change { UserChatChannelMembership.count }
          expect(result).to be_a_success
        end
      end

      context "when chat_allowed_groups includes everyone" do
        before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone] }

        before do
          channel_1.add(user_1)
          channel_1.add(user_2)
          channel_2.add(user_1)
          channel_2.add(user_2)
          channel_1.add(admin_1)
          channel_1.add(admin_2)
          Group.refresh_automatic_groups!
        end

        it "does nothing" do
          expect { result }.not_to change { UserChatChannelMembership.count }
          expect(result).to fail_a_policy(:not_everyone_allowed)
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
        Group.refresh_automatic_groups!
      end

      context "when channel category not read_restricted with no category_groups" do
        before do
          channel_1.chatable.update!(read_restricted: false)
          channel_1.chatable.category_groups.destroy_all
        end

        it "does nothing because everyone group has full permission" do
          expect { result }.not_to change { UserChatChannelMembership.count }
          expect(result).to be_a_success
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

        it "removes the destroyed_group_user_ids from the channel" do
          expect(result).to be_a_success
          expect(
            UserChatChannelMembership.where(
              user: [user_1, user_2],
              chat_channel: [channel_1],
            ).count,
          ).to eq(0)
        end

        it "does not remove any admin destroyed_group_user_ids from the channel" do
          expect(result).to be_a_success
          expect(
            UserChatChannelMembership.where(
              user: [admin_1, admin_2],
              chat_channel: [channel_1],
            ).count,
          ).to eq(2)
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

          it "removes the destroyed_group_user_ids from the channel" do
            expect(result).to be_a_success
            expect(
              UserChatChannelMembership.where(
                user: [user_1, user_2],
                chat_channel: [channel_1],
              ).count,
            ).to eq(1)
          end
        end
      end
    end
  end
end
