# frozen_string_literal: true

describe "Automatic user removal from channels" do
  fab!(:user_1) { Fabricate(:user, trust_level: 1) }
  fab!(:user_2) { Fabricate(:user, trust_level: 3) }

  fab!(:user_1_guardian) { Guardian.new(user_1) }

  fab!(:secret_group) { Fabricate(:group) }
  fab!(:private_category) { Fabricate(:private_category, group: secret_group) }

  fab!(:public_channel) { Fabricate(:chat_channel) }
  fab!(:private_channel) { Fabricate(:chat_channel, chatable: private_category) }
  fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

  before do
    SiteSetting.chat_enabled = true
    Jobs.run_immediately!

    secret_group.add(user_1)
    public_channel.add(user_1)
    private_channel.add(user_1)
    public_channel.add(user_2)

    CategoryGroup.create(category: public_channel.chatable, group_id: Group::AUTO_GROUPS[:everyone])
  end

  context "when the chat_allowed_groups site setting changes" do
    it "removes the user who is no longer in chat_allowed_groups" do
      expect { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_3] }.to change {
        Chat::UserChatChannelMembership.count
      }.by(-3)

      expect(
        Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: public_channel),
      ).to eq(false)
      expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
        public_channel.id,
      )

      expect(
        Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel),
      ).to eq(false)
      expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
        private_channel.id,
      )
    end

    it "does not remove the user who is in one of the chat_allowed_groups" do
      user_2.change_trust_level!(4)

      expect { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_3] }.to change {
        Chat::UserChatChannelMembership.count
      }.by(-3)
      expect(
        Chat::UserChatChannelMembership.exists?(user: user_2, chat_channel: public_channel),
      ).to eq(true)
    end

    it "removes users from their DM channels" do
      expect { SiteSetting.chat_allowed_groups = "" }.to change {
        Chat::UserChatChannelMembership.count
      }.by(-5)

      expect(Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: dm_channel)).to eq(
        false,
      )
      expect(Chat::UserChatChannelMembership.exists?(user: user_2, chat_channel: dm_channel)).to eq(
        false,
      )
    end

    context "for staff users" do
      fab!(:staff_user) { Fabricate(:admin) }

      it "does not remove them from chat channels" do
        public_channel.add(staff_user)
        private_channel.add(staff_user)

        expect(
          Chat::UserChatChannelMembership.where(
            user: staff_user,
            chat_channel: [public_channel, private_channel],
          ).count,
        ).to eq(2)

        SiteSetting.chat_allowed_groups = ""

        expect(
          Chat::UserChatChannelMembership.where(
            user: staff_user,
            chat_channel: [public_channel, private_channel],
          ).count,
        ).to eq(2)
      end

      it "does not remove them from DM channels" do
        staff_dm_channel = Fabricate(:direct_message_channel, users: [user_1, staff_user])

        expect(
          Chat::UserChatChannelMembership.where(
            user: staff_user,
            chat_channel: [staff_dm_channel],
          ).count,
        ).to eq(1)
      end
    end
  end

  context "when a user is removed from a group" do
    context "when the user is no longer in any chat_allowed_groups" do
      fab!(:group)

      before do
        group.add(user_1)
        SiteSetting.chat_allowed_groups = group.id
      end

      it "removes the user from all channels" do
        expect(Chat::UserChatChannelMembership.where(user: user_1).count).to eq(3)

        group.remove(user_1)

        expect(Chat::UserChatChannelMembership.where(user: user_1).count).to eq(0)
      end

      context "for staff users" do
        fab!(:staff_user) { Fabricate(:admin) }

        it "does not remove them from public channels" do
          public_channel.add(staff_user)
          private_channel.add(staff_user)
          group.add(staff_user)
          group.remove(staff_user)

          expect(
            Chat::UserChatChannelMembership.where(
              user: staff_user,
              chat_channel: [public_channel, private_channel],
            ).count,
          ).to eq(2)
        end
      end
    end

    context "when a user is removed from a private category group" do
      context "when the user is in another group that can interact with the channel" do
        fab!(:stealth_group) { Fabricate(:group) }

        before do
          CategoryGroup.create!(
            category: private_category,
            group: stealth_group,
            permission_type: CategoryGroup.permission_types[:full],
          )
          stealth_group.add(user_1)
        end

        it "does not remove them from the corresponding channel" do
          secret_group.remove(user_1)

          expect(
            Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel),
          ).to eq(true)
          expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).to include(
            private_channel.id,
          )
        end
      end

      context "when the user is in no other groups that can interact with the channel" do
        it "removes them from the corresponding channel" do
          secret_group.remove(user_1)

          expect(
            Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel),
          ).to eq(false)
          expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
            private_channel.id,
          )
        end
      end
    end
  end

  context "when a category is updated" do
    context "when the group's permission changes from reply+see to just see for the category" do
      it "removes the user from the corresponding category channel" do
        private_category.update!(permissions: { secret_group.id => :readonly })

        expect(
          Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel),
        ).to eq(false)
        expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
          private_channel.id,
        )
      end

      context "for staff users" do
        fab!(:staff_user) { Fabricate(:admin) }

        it "does not remove them from the channel" do
          secret_group.add(staff_user)
          private_channel.add(staff_user)
          private_category.update!(permissions: { secret_group.id => :readonly })

          expect(
            Chat::UserChatChannelMembership.exists?(
              user: staff_user,
              chat_channel: private_channel,
            ),
          ).to eq(true)
        end
      end
    end

    context "when the secret_group is no longer allowed to access the private category" do
      it "removes the user from the corresponding category channel" do
        private_category.update!(permissions: { Group::AUTO_GROUPS[:staff] => :full })

        expect(
          Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel),
        ).to eq(false)
        expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
          private_channel.id,
        )
      end

      context "for staff users" do
        fab!(:staff_user) { Fabricate(:admin) }

        it "does not remove them from the channel" do
          secret_group.add(staff_user)
          private_channel.add(staff_user)
          private_category.update!(permissions: {})

          expect(
            Chat::UserChatChannelMembership.exists?(
              user: staff_user,
              chat_channel: private_channel,
            ),
          ).to eq(true)
        end
      end
    end
  end

  context "when a group is destroyed" do
    context "when it was the last group on the private category" do
      it "remove users because the category defaults to staff having full access" do
        secret_group.destroy!

        expect(
          Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel),
        ).to eq(false)
        expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).to_not include(
          private_channel.id,
        )

        expect(
          Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: public_channel),
        ).to eq(true)
        expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).to include(
          public_channel.id,
        )
      end
    end

    context "when there is another group on the private category" do
      before do
        CategoryGroup.create(group_id: Group::AUTO_GROUPS[:staff], category: private_category)
      end

      it "only removes users who are not in that group" do
        secret_group.destroy!

        expect(
          Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: private_channel),
        ).to eq(false)
        expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).not_to include(
          private_channel.id,
        )

        expect(
          Chat::UserChatChannelMembership.exists?(user: user_1, chat_channel: public_channel),
        ).to eq(true)
        expect(Chat::ChannelFetcher.all_secured_channel_ids(user_1_guardian)).to include(
          public_channel.id,
        )
      end
    end
  end
end
