# frozen_string_literal: true

RSpec.describe Chat::ChannelMembershipManager do
  fab!(:user)
  fab!(:channel1) { Fabricate(:category_channel) }
  fab!(:channel2) { Fabricate(:category_channel) }
  let!(:plugin) { Plugin::Instance.new }
  let!(:deny_block) { Proc.new { false } }
  let!(:allow_block) { Proc.new { true } }

  describe "#all_for_user" do
    it "works with plugin modifier" do
      DiscoursePluginRegistry.register_modifier(plugin, :list_user_channels_modifier, &deny_block)
      action = described_class.all_for_user(user)
      expect(action).to eq(false)

      DiscoursePluginRegistry.register_modifier(plugin, :list_user_channels_modifier, &allow_block)
      action = described_class.all_for_user(user)
      expect(action).to eq(true)
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, :list_user_channels_modifier, &deny_block)
      DiscoursePluginRegistry.unregister_modifier(
        plugin,
        :list_user_channels_modifier,
        &allow_block
      )
    end
  end

  describe ".find_for_user" do
    let!(:membership) do
      Fabricate(:user_chat_channel_membership, user: user, chat_channel: channel1, following: true)
    end

    it "returns nil if it cannot find a membership for the user and channel" do
      expect(described_class.new(channel2).find_for_user(user)).to be_blank
    end

    it "returns the membership for the channel and user" do
      membership = described_class.new(channel1).find_for_user(user)
      expect(membership.chat_channel_id).to eq(channel1.id)
      expect(membership.user_id).to eq(user.id)
      expect(membership.following).to eq(true)
    end

    it "scopes by following and returns nil if it does not match the scope" do
      membership.update!(following: false)
      expect(described_class.new(channel1).find_for_user(user, following: true)).to be_blank
    end
  end

  describe ".follow" do
    it "creates a membership if one does not exist for the user and channel already" do
      membership = nil
      expect { membership = described_class.new(channel1).follow(user) }.to change {
        Chat::UserChatChannelMembership.count
      }.by(1)
      expect(membership.following).to eq(true)
      expect(membership.chat_channel).to eq(channel1)
      expect(membership.user).to eq(user)
    end

    it "enqueues user_count recalculation and marks user_count_stale as true" do
      described_class.new(channel1).follow(user)
      expect(channel1.reload.user_count_stale).to eq(true)
      expect_job_enqueued(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: channel1.id,
        },
      )
    end

    it "updates the membership to following if it already existed" do
      membership =
        Fabricate(
          :user_chat_channel_membership,
          user: user,
          chat_channel: channel1,
          following: false,
        )
      expect { membership = described_class.new(channel1).follow(user) }.not_to change {
        Chat::UserChatChannelMembership.count
      }
      expect(membership.reload.following).to eq(true)
    end

    it "works with plugin modifier" do
      DiscoursePluginRegistry.register_modifier(plugin, :follow_modifier, &deny_block)

      action = described_class.new(channel1).follow(user)
      expect(action).to eq(false)

      DiscoursePluginRegistry.register_modifier(plugin, :follow_modifier, &allow_block)
      action = described_class.new(channel1).follow(user)

      expect(action).to eq(true)
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, :follow_modifier, &deny_block)
      DiscoursePluginRegistry.unregister_modifier(plugin, :follow_modifier, &allow_block)
    end
  end

  describe ".unfollow" do
    it "does nothing if the user is not following the channel" do
      expect(described_class.new(channel2).unfollow(user)).to be_blank
    end

    it "updates following for the membership to false and recalculates the user count" do
      membership =
        Fabricate(
          :user_chat_channel_membership,
          user: user,
          chat_channel: channel1,
          following: true,
        )
      described_class.new(channel1).unfollow(user)
      membership.reload
      expect(membership.following).to eq(false)
      expect(channel1.reload.user_count_stale).to eq(true)
      expect_job_enqueued(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: channel1.id,
        },
      )
    end

    it "does not recalculate user count if the user was already not following the channel" do
      membership =
        Fabricate(
          :user_chat_channel_membership,
          user: user,
          chat_channel: channel1,
          following: false,
        )
      expect_not_enqueued_with(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: channel1.id,
        },
      ) { described_class.new(channel1).unfollow(user) }
      expect(channel1.reload.user_count_stale).to eq(false)
    end
  end
end
