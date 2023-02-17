# frozen_string_literal: true

describe "Automatic user removal from channels" do
  fab!(:user_1) { Fabricate(:user, trust_level: TrustLevel[1]) }
  let(:user_1_guardian) { Guardian.new(user_1) }
  fab!(:user_2) { Fabricate(:user, trust_level: TrustLevel[1]) }

  fab!(:secret_group) { Fabricate(:group) }
  fab!(:private_category) { Fabricate(:private_category, group: secret_group) }

  before do
    SiteSetting.chat_enabled = true
    Group.refresh_automatic_groups!
    Jobs.run_immediately!
  end

  context "for all channel types" do
    fab!(:public_channel) { Fabricate(:chat_channel) }
    fab!(:private_channel) { Fabricate(:chat_channel, chatable: private_category) }
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

    before do
      secret_group.add(user_1)
      public_channel.add(user_1)
      private_channel.add(user_1)

      public_channel.add(user_2)
      user_2.change_trust_level!(TrustLevel[4])
    end

    it "removes the user who is no longer in chat_allowed_groups" do
      expect { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_3] }.to change {
        UserChatChannelMembership.count
      }.by(-3)

      expect(UserChatChannelMembership.exists?(user: user_1, chat_channel: public_channel)).to eq(
        false,
      )
      expect(Chat::ChatChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
        public_channel.id,
      )

      expect(UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel)).to eq(
        false,
      )
      expect(Chat::ChatChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
        private_channel.id,
      )

      expect(UserChatChannelMembership.exists?(user: user_1, chat_channel: dm_channel)).to eq(false)
      expect(Chat::ChatChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
        dm_channel.id,
      )
    end

    it "does not remove the user who is in one of the chat_allowed_groups" do
      expect { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_3] }.to change {
        UserChatChannelMembership.count
      }.by(-2)
      expect(UserChatChannelMembership.exists?(user: user_2, chat_channel: public_channel)).to eq(
        true,
      )
    end

    it "does not remove users from their DM channels" do
      expect { SiteSetting.chat_allowed_groups = "" }.to change {
        UserChatChannelMembership.count
      }.by(-3)

      expect(UserChatChannelMembership.exists?(user: user_1, chat_channel: dm_channel)).to eq(true)
      expect(UserChatChannelMembership.exists?(user: user_2, chat_channel: dm_channel)).to eq(true)
    end

    it "does not remove staff users" do
      staff_user = Fabricate(:admin)
      public_channel.add(staff_user)
      private_channel.add(staff_user)
      SiteSetting.chat_allowed_groups = ""
      expect(
        UserChatChannelMembership.exists?(user: staff_user, chat_channel: public_channel),
      ).to eq(true)
      expect(
        UserChatChannelMembership.exists?(user: staff_user, chat_channel: private_channel),
      ).to eq(true)
    end
  end

  context "for private channels" do
    fab!(:private_channel) { Fabricate(:chat_channel, chatable: private_category) }

    before do
      secret_group.add(user_1)
      private_channel.add(user_1)
    end

    it "removes the user when they are removed from all groups which have permission to see the private category" do
      secret_group.remove(user_1)
      expect(UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel)).to eq(
        false,
      )
      expect(Chat::ChatChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
        private_channel.id,
      )
    end

    it "removes the user when the group's permission changes from reply+see to just see for the category" do
      private_category.update!(permissions: { secret_group.id => :readonly })
      expect(UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel)).to eq(
        false,
      )
      expect(Chat::ChatChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
        private_channel.id,
      )
    end

    it "removes the user when the group is no longer allowed to access the private category" do
      private_category.category_groups.find_by(group: secret_group).destroy!
      expect(UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel)).to eq(
        false,
      )
      expect(Chat::ChatChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
        private_channel.id,
      )
    end
  end
end
