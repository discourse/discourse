# frozen_string_literal: true

describe Chat::ChannelFetcher do
  fab!(:category) { Fabricate(:category, name: "support") }
  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:category_channel) { Fabricate(:category_channel, chatable: category, slug: "support") }
  fab!(:dm_channel1) { Fabricate(:direct_message) }
  fab!(:dm_channel2) { Fabricate(:direct_message) }
  fab!(:direct_message_channel1) { Fabricate(:direct_message_channel, chatable: dm_channel1) }
  fab!(:direct_message_channel2) { Fabricate(:direct_message_channel, chatable: dm_channel2) }
  fab!(:chatters) { Fabricate(:group) }
  fab!(:user1) { Fabricate(:user, group_ids: [chatters.id]) }
  fab!(:user2) { Fabricate(:user) }

  def guardian
    Guardian.new(user1)
  end

  def memberships
    Chat::UserChatChannelMembership.where(user: user1)
  end

  before { SiteSetting.chat_allowed_groups = chatters }

  describe ".structured" do
    it "returns open channel only" do
      category_channel.user_chat_channel_memberships.create!(user: user1, following: true)

      channels = described_class.structured(guardian)[:public_channels]

      expect(channels).to contain_exactly(category_channel)

      category_channel.closed!(Discourse.system_user)
      channels = described_class.structured(guardian)[:public_channels]

      expect(channels).to be_blank
    end

    it "returns followed channel only" do
      channels = described_class.structured(guardian)[:public_channels]

      expect(channels).to be_blank

      category_channel.user_chat_channel_memberships.create!(user: user1, following: true)
      channels = described_class.structured(guardian)[:public_channels]

      expect(channels).to contain_exactly(category_channel)
    end
  end

  describe ".tracking_state" do
    context "when user is member of the channel" do
      before do
        Fabricate(:user_chat_channel_membership, chat_channel: category_channel, user: user1)
      end

      context "with unread messages" do
        before do
          Fabricate(:chat_message, chat_channel: category_channel, message: "hi", user: user2)
          Fabricate(:chat_message, chat_channel: category_channel, message: "bonjour", user: user2)
        end

        it "returns the correct count" do
          tracking_state =
            described_class.tracking_state([category_channel.id], Guardian.new(user1))
          expect(tracking_state.find_channel(category_channel.id).unread_count).to eq(2)
        end
      end

      context "with no unread messages" do
        it "returns the correct count" do
          tracking_state =
            described_class.tracking_state([category_channel.id], Guardian.new(user1))
          expect(tracking_state.find_channel(category_channel.id).unread_count).to eq(0)
        end
      end

      context "when last unread message has been deleted" do
        fab!(:last_unread) do
          Fabricate(:chat_message, chat_channel: category_channel, message: "hi", user: user2)
        end

        before { last_unread.update!(deleted_at: Time.zone.now) }

        it "returns the correct count" do
          tracking_state =
            described_class.tracking_state([category_channel.id], Guardian.new(user1))
          expect(tracking_state.find_channel(category_channel.id).unread_count).to eq(0)
        end
      end
    end

    context "when user is not member of the channel" do
      context "when the channel has new messages" do
        before do
          Fabricate(:chat_message, chat_channel: category_channel, message: "hi", user: user2)
        end

        it "returns the correct count" do
          tracking_state =
            described_class.tracking_state([category_channel.id], Guardian.new(user1))
          expect(tracking_state.find_channel(category_channel.id).unread_count).to eq(0)
        end
      end
    end
  end

  describe ".all_secured_channel_ids" do
    it "returns nothing by default if the user has no memberships" do
      expect(described_class.all_secured_channel_ids(guardian)).to eq([])
    end

    context "when the user has memberships to all the channels" do
      before do
        Chat::UserChatChannelMembership.create!(
          user: user1,
          chat_channel: category_channel,
          following: true,
        )
        Chat::UserChatChannelMembership.create!(
          user: user1,
          chat_channel: direct_message_channel1,
          following: true,
          notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
        )
      end

      it "returns category channel because they are public by default" do
        expect(described_class.all_secured_channel_ids(guardian)).to match_array(
          [category_channel.id],
        )
      end

      it "returns all the channels if the user is a member of the DM channel also" do
        Chat::DirectMessageUser.create!(user: user1, direct_message: dm_channel1)
        expect(described_class.all_secured_channel_ids(guardian)).to match_array(
          [category_channel.id, direct_message_channel1.id],
        )
      end

      it "does not include the category channel if the category is a private category the user cannot see" do
        category_channel.update!(chatable: private_category)
        expect(described_class.all_secured_channel_ids(guardian)).to be_empty
        GroupUser.create!(group: private_category.groups.last, user: user1)
        expect(described_class.all_secured_channel_ids(guardian)).to match_array(
          [category_channel.id],
        )
      end

      context "when restricted category" do
        fab!(:group)
        fab!(:group_user) { Fabricate(:group_user, group: group, user: user1) }

        it "does not include the category channel for member of group with readonly access" do
          category_channel.update!(
            chatable:
              Fabricate(
                :private_category,
                group: group,
                permission_type: CategoryGroup.permission_types[:readonly],
              ),
          )
          expect(described_class.all_secured_channel_ids(guardian)).to be_empty
        end

        it "includes the category channel for member of group with create_post access" do
          category_channel.update!(
            chatable:
              Fabricate(
                :private_category,
                group: group,
                permission_type: CategoryGroup.permission_types[:create_post],
              ),
          )
          expect(described_class.all_secured_channel_ids(guardian)).to match_array(
            [category_channel.id],
          )
        end

        it "includes the category channel for member of group with full access" do
          category_channel.update!(
            chatable:
              Fabricate(
                :private_category,
                group: group,
                permission_type: CategoryGroup.permission_types[:full],
              ),
          )
          expect(described_class.all_secured_channel_ids(guardian)).to match_array(
            [category_channel.id],
          )
        end
      end
    end
  end

  describe "#secured_public_channels" do
    let(:following) { false }

    it "does not include DM channels" do
      expect(
        described_class.secured_public_channels(guardian, following: following).map(&:id),
      ).to match_array([category_channel.id])
    end

    it "returns an empty array when public channels are disabled" do
      SiteSetting.enable_public_channels = false

      expect(described_class.secured_public_channels(guardian, following: nil)).to be_empty
    end

    it "can filter by channel name, or category name" do
      expect(
        described_class.secured_public_channels(
          guardian,
          following: following,
          filter: "support",
        ).map(&:id),
      ).to match_array([category_channel.id])

      category_channel.update!(name: "cool stuff")

      expect(
        described_class.secured_public_channels(
          guardian,
          following: following,
          filter: "cool stuff",
        ).map(&:id),
      ).to match_array([category_channel.id])
    end

    it "can filter by an array of slugs" do
      expect(
        described_class.secured_public_channels(guardian, slugs: ["support"]).map(&:id),
      ).to match_array([category_channel.id])
    end

    it "returns nothing if the array of slugs is empty" do
      expect(described_class.secured_public_channels(guardian, slugs: []).map(&:id)).to eq([])
    end

    it "can filter by status" do
      expect(
        described_class.secured_public_channels(guardian, status: "closed").map(&:id),
      ).to match_array([])

      category_channel.closed!(Discourse.system_user)

      expect(
        described_class.secured_public_channels(guardian, status: "closed").map(&:id),
      ).to match_array([category_channel.id])
    end

    it "can filter by following" do
      expect(
        described_class.secured_public_channels(guardian, following: true).map(&:id),
      ).to be_blank
    end

    it "can filter by not following" do
      category_channel.user_chat_channel_memberships.create!(user: user1, following: false)
      another_channel = Fabricate(:category_channel)

      expect(
        described_class.secured_public_channels(guardian, following: false).map(&:id),
      ).to match_array([category_channel.id, another_channel.id])
    end

    it "ensures offset is >= 0" do
      expect(
        described_class.secured_public_channels(guardian, offset: -235).map(&:id),
      ).to match_array([category_channel.id])
    end

    it "ensures limit is > 0" do
      expect(
        described_class.secured_public_channels(guardian, limit: -1, offset: 0).map(&:id),
      ).to match_array([category_channel.id])
    end

    it "ensures limit has a max value" do
      over_limit = Chat::ChannelFetcher::MAX_PUBLIC_CHANNEL_RESULTS + 1
      over_limit.times { Fabricate(:category_channel) }

      expect(described_class.secured_public_channels(guardian, limit: over_limit).length).to eq(
        Chat::ChannelFetcher::MAX_PUBLIC_CHANNEL_RESULTS,
      )
    end

    it "does not show the user category channels they cannot access" do
      category_channel.update!(chatable: private_category)
      expect(
        described_class.secured_public_channels(guardian, following: following).map(&:id),
      ).to be_empty
    end

    context "when scoping to the user's channel memberships" do
      let(:following) { true }

      it "only returns channels where the user is a member and is following the channel" do
        expect(
          described_class.secured_public_channels(guardian, following: following).map(&:id),
        ).to be_empty

        Chat::UserChatChannelMembership.create!(
          user: user1,
          chat_channel: category_channel,
          following: true,
        )

        expect(
          described_class.secured_public_channels(guardian, following: following).map(&:id),
        ).to match_array([category_channel.id])
      end

      it "includes the unread count based on mute settings" do
        Chat::UserChatChannelMembership.create!(
          user: user1,
          chat_channel: category_channel,
          following: true,
        )

        Fabricate(:chat_message, user: user2, chat_channel: category_channel)
        Fabricate(:chat_message, user: user2, chat_channel: category_channel)

        resolved_memberships = memberships
        result =
          described_class.tracking_state(resolved_memberships.map(&:chat_channel_id), guardian)

        expect(result.channel_tracking[category_channel.id][:unread_count]).to eq(2)

        resolved_memberships = memberships
        resolved_memberships.last.update!(muted: true)
        result =
          described_class.tracking_state(resolved_memberships.map(&:chat_channel_id), guardian)

        expect(result.channel_tracking[category_channel.id][:unread_count]).to eq(0)
      end
    end
  end

  describe ".secured_direct_message_channels" do
    it "includes direct message channels the user is a member of ordered by last_message.created_at" do
      Fabricate(
        :user_chat_channel_membership_for_dm,
        chat_channel: direct_message_channel1,
        user: user1,
        following: true,
      )
      Chat::DirectMessageUser.create!(direct_message: dm_channel1, user: user1)
      Chat::DirectMessageUser.create!(direct_message: dm_channel1, user: user2)
      Fabricate(
        :user_chat_channel_membership_for_dm,
        chat_channel: direct_message_channel2,
        user: user1,
        following: true,
      )
      Chat::DirectMessageUser.create!(direct_message: dm_channel2, user: user1)
      Chat::DirectMessageUser.create!(direct_message: dm_channel2, user: user2)

      dm_1 = Fabricate(:chat_message, user: user1, chat_channel: direct_message_channel1)
      dm_2 = Fabricate(:chat_message, user: user1, chat_channel: direct_message_channel2)

      direct_message_channel1.update!(last_message: dm_1)
      direct_message_channel1.last_message.update!(created_at: 1.day.ago)
      direct_message_channel2.update!(last_message: dm_2)
      direct_message_channel2.last_message.update!(created_at: 1.hour.ago)

      expect(described_class.secured_direct_message_channels(user1.id, guardian).map(&:id)).to eq(
        [direct_message_channel2.id, direct_message_channel1.id],
      )
    end

    it "does not include direct message channels where the user is a member but not a direct_message_user" do
      Fabricate(
        :user_chat_channel_membership_for_dm,
        chat_channel: direct_message_channel1,
        user: user1,
        following: true,
      )
      Chat::DirectMessageUser.create!(direct_message: dm_channel1, user: user2)

      expect(
        described_class.secured_direct_message_channels(user1.id, guardian).map(&:id),
      ).not_to include(direct_message_channel1.id)
    end

    it "includes the unread count based on mute settings for the user's channel membership" do
      membership =
        Fabricate(
          :user_chat_channel_membership_for_dm,
          chat_channel: direct_message_channel1,
          user: user1,
          following: true,
        )
      Chat::DirectMessageUser.create!(direct_message: dm_channel1, user: user1)
      Chat::DirectMessageUser.create!(direct_message: dm_channel1, user: user2)

      Fabricate(:chat_message, user: user2, chat_channel: direct_message_channel1)
      Fabricate(:chat_message, user: user2, chat_channel: direct_message_channel1)
      resolved_memberships = memberships

      target_membership =
        resolved_memberships.find { |mem| mem.chat_channel_id == direct_message_channel1.id }
      result = described_class.tracking_state([direct_message_channel1.id], guardian)
      expect(result.channel_tracking[target_membership.chat_channel_id][:unread_count]).to eq(2)

      resolved_memberships = memberships
      target_membership =
        resolved_memberships.find { |mem| mem.chat_channel_id == direct_message_channel1.id }
      target_membership.update!(muted: true)
      result = described_class.tracking_state([direct_message_channel1.id], guardian)
      expect(result.channel_tracking[target_membership.chat_channel_id][:unread_count]).to eq(0)
    end
  end

  describe ".unreads_total" do
    it "returns correct totals for DMs and mentions" do
      result = described_class.unreads_total(guardian)

      expect(result).to eq(0)

      Fabricate(
        :user_chat_channel_membership_for_dm,
        chat_channel: direct_message_channel1,
        user: user1,
        following: true,
      )
      Chat::DirectMessageUser.create!(direct_message: dm_channel1, user: user1)
      Chat::DirectMessageUser.create!(direct_message: dm_channel1, user: user2)
      Fabricate(
        :user_chat_channel_membership_for_dm,
        chat_channel: direct_message_channel2,
        user: user1,
        following: true,
      )
      Chat::DirectMessageUser.create!(direct_message: dm_channel2, user: user1)
      Chat::DirectMessageUser.create!(direct_message: dm_channel2, user: user2)

      dm_1 = Fabricate(:chat_message, user: user1, chat_channel: direct_message_channel1)
      dm_2 = Fabricate(:chat_message, user: user1, chat_channel: direct_message_channel2)

      direct_message_channel1.update!(last_message: dm_1)
      direct_message_channel1.last_message.update!(created_at: 1.day.ago)
      direct_message_channel2.update!(last_message: dm_2)
      direct_message_channel2.last_message.update!(created_at: 1.hour.ago)

      result = described_class.unreads_total(guardian)
      expect(result).to eq(2)

      membership =
        Fabricate(:user_chat_channel_membership, chat_channel: category_channel, user: user1)
      message =
        Fabricate(:chat_message, chat_channel: category_channel, message: "bonjour", user: user2)
      notification =
        Notification.create!(
          notification_type: Notification.types[:chat_mention],
          user_id: user1.id,
          data: { chat_message_id: message.id, chat_channel_id: category_channel.id }.to_json,
        )
      Chat::UserMention.create!(notifications: [notification], user: user1, chat_message: message)

      result = described_class.unreads_total(guardian)
      expect(result).to eq(3) # 2 DMs + 1 mention

      # mark mention as read
      membership.update!(last_read_message_id: message.id)

      result = described_class.unreads_total(guardian)
      expect(result).to eq(2) # only 2 DMs left unread
    end
  end

  describe ".find_with_access_check" do
    it "raises NotFound if the channel does not exist" do
      category_channel.destroy!
      expect {
        described_class.find_with_access_check(category_channel.id, guardian)
      }.to raise_error(Discourse::NotFound)
    end

    it "raises InvalidAccess if the user cannot see the channel" do
      category_channel.update!(chatable: private_category)
      expect {
        described_class.find_with_access_check(category_channel.id, guardian)
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "returns the chat channel if it is found and accessible" do
      expect(described_class.find_with_access_check(category_channel.id, guardian)).to eq(
        category_channel,
      )
    end
  end
end
