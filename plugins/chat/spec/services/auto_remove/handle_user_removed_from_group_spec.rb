# frozen_string_literal: true

RSpec.describe Chat::Service::AutoRemove::HandleUserRemovedFromGroup do
  describe ".call" do
    let(:params) { { user_id: removed_user.id } }
    subject(:result) { described_class.call(params) }

    fab!(:removed_user) { Fabricate(:user) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }

    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [removed_user, user_1]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [removed_user, user_2]) }

    fab!(:public_channel_1) { Fabricate(:chat_channel) }
    fab!(:public_channel_2) { Fabricate(:chat_channel) }

    it "fails model if user is deleted" do
      removed_user.destroy!
      expect(result).to fail_to_find_a_model(:user)
    end

    context "when the user is no longer in any of the chat_allowed_groups" do
      before do
        SiteSetting.chat_allowed_groups = Fabricate(:group).id
        public_channel_1.add(removed_user)
        public_channel_2.add(removed_user)
      end

      it "removes them from public channels" do
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [removed_user],
            chat_channel: [public_channel_1, public_channel_2],
          ).count,
        ).to eq(0)
      end

      it "does not remove them from direct message channels" do
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [removed_user],
            chat_channel: [dm_channel_1, dm_channel_2],
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
              user_ids: [removed_user.id],
              channel_id: public_channel_1.id,
            },
          ),
        ).to eq(true)
        expect(
          job_enqueued?(
            job: :kick_users_from_channel,
            at: 5.seconds.from_now,
            args: {
              user_ids: [removed_user.id],
              channel_id: public_channel_2.id,
            },
          ),
        ).to eq(true)
      end

      it "logs a staff action" do
        expect(result).to be_a_success
        action = UserHistory.last
        expect(action.details).to eq(
          "users_removed: 1\nchannel_id: #{public_channel_2.id}\nevent: user_removed_from_group",
        )
        expect(action.acting_user_id).to eq(Discourse.system_user.id)
        expect(action.custom_type).to eq("chat_auto_remove_membership")
      end

      context "when the user is staff" do
        fab!(:removed_user) { Fabricate(:admin) }

        it "does not remove them from public channels" do
          expect(result).to be_a_success
          expect(
            UserChatChannelMembership.where(
              user: [removed_user],
              chat_channel: [public_channel_1, public_channel_2],
            ).count,
          ).to eq(2)
        end
      end
    end

    context "for private channels" do
      fab!(:group_1) { Fabricate(:group) }
      fab!(:group_2) { Fabricate(:group) }
      fab!(:private_category) { Fabricate(:private_category, group: group_1) }
      fab!(:private_channel_1) { Fabricate(:chat_channel, chatable: private_category) }

      before do
        group_1.add(removed_user)
        group_2.add(removed_user)
        SiteSetting.chat_allowed_groups = group_1.id.to_s + "|" + group_2.id.to_s
        CategoryGroup.create(
          category: private_category,
          group: group_2,
          permission_type: CategoryGroup.permission_types[:full],
        )
        private_channel_1.add(removed_user)
      end

      context "when the user remains in one of the groups that can access a private channel" do
        before { group_1.remove(removed_user) }

        it "does not remove them from that channel" do
          expect(result).to be_a_success
          expect(
            UserChatChannelMembership.where(
              user: [removed_user],
              chat_channel: [private_channel_1],
            ).count,
          ).to eq(1)
        end
      end

      context "when the user in remains in one of the groups but that group only has readonly access to the channel" do
        before do
          CategoryGroup.find_by(group: group_2, category: private_category).update!(
            permission_type: CategoryGroup.permission_types[:readonly],
          )
          group_1.remove(removed_user)
        end

        it "removes them from that channel" do
          expect(result).to be_a_success
          expect(
            UserChatChannelMembership.where(
              user: [removed_user],
              chat_channel: [private_channel_1],
            ).count,
          ).to eq(0)
        end

        context "when the user is staff" do
          fab!(:removed_user) { Fabricate(:admin) }

          it "does not remove them from that channel" do
            expect(result).to be_a_success
            expect(
              UserChatChannelMembership.where(
                user: [removed_user],
                chat_channel: [private_channel_1],
              ).count,
            ).to eq(1)
          end
        end
      end

      context "when the user is no longer in any group that can access a private channel" do
        before do
          group_1.remove(removed_user)
          group_2.remove(removed_user)
        end

        it "removes them from that channel" do
          expect(result).to be_a_success
          expect(
            UserChatChannelMembership.where(
              user: [removed_user],
              chat_channel: [private_channel_1],
            ).count,
          ).to eq(0)
        end

        context "when the user is staff" do
          fab!(:removed_user) { Fabricate(:admin) }

          it "does not remove them from that channel" do
            expect(result).to be_a_success
            expect(
              UserChatChannelMembership.where(
                user: [removed_user],
                chat_channel: [private_channel_1],
              ).count,
            ).to eq(1)
          end
        end
      end
    end
  end
end
