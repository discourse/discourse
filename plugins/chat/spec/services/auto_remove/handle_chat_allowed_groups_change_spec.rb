# frozen_string_literal: true

RSpec.describe Chat::Service::AutoRemove::HandleChatAllowedGroupsChange do
  describe ".call" do
    let(:params) { { new_allowed_groups: new_allowed_groups } }
    subject(:result) { described_class.call(params) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:admin_1) { Fabricate(:admin) }
    fab!(:admin_2) { Fabricate(:admin) }

    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [admin_1, user_1]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

    fab!(:public_channel_1) { Fabricate(:chat_channel) }
    fab!(:public_channel_2) { Fabricate(:chat_channel) }

    context "when new_allowed_groups is empty" do
      let(:new_allowed_groups) { "" }

      before do
        public_channel_1.add(user_1)
        public_channel_1.add(user_2)
        public_channel_2.add(user_1)
        public_channel_2.add(user_2)
        public_channel_1.add(admin_1)
        public_channel_1.add(admin_2)
      end

      it "removes users from all public channels" do
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [user_1, user_2],
            chat_channel: [public_channel_1, public_channel_2],
          ).count,
        ).to eq(0)
      end

      it "does not remove admin users from public channels" do
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [admin_1, admin_2],
            chat_channel: [public_channel_1],
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
              channel_id: public_channel_1.id,
            },
          ),
        ).to eq(true)
        expect(
          job_enqueued?(
            job: :kick_users_from_channel,
            at: 5.seconds.from_now,
            args: {
              user_ids: [user_1.id, user_2.id],
              channel_id: public_channel_2.id,
            },
          ),
        ).to eq(true)
      end

      it "logs a staff action" do
        expect(result).to be_a_success
        action = UserHistory.last
        expect(action.details).to eq(
          "users_removed: 2\nchannel_id: #{public_channel_2.id}\nevent: chat_allowed_groups_changed",
        )
        expect(action.acting_user_id).to eq(Discourse.system_user.id)
        expect(action.custom_type).to eq("chat_auto_remove_membership")
      end
    end

    context "when new_allowed_groups includes all the users in public channels" do
      let(:new_allowed_groups) { Group::AUTO_GROUPS[:trust_level_1] }

      before do
        public_channel_1.add(user_1)
        public_channel_2.add(user_1)
        Group.refresh_automatic_groups!
      end

      it "does nothing" do
        expect { result }.not_to change { UserChatChannelMembership.count }
        expect(result).to be_a_success
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
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [user_1, user_2],
            chat_channel: [public_channel_1, public_channel_2],
          ).count,
        ).to eq(2)
      end

      it "does not remove them from direct message channels" do
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [user_1, user_2],
            chat_channel: [dm_channel_2],
          ).count,
        ).to eq(2)
      end
    end
  end
end
