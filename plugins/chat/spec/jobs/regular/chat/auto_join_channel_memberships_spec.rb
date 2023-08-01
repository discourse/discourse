# frozen_string_literal: true

require "rails_helper"

describe Jobs::Chat::AutoJoinChannelMemberships do
  let(:user) { Fabricate(:user, last_seen_at: 15.minutes.ago) }
  let(:category) { Fabricate(:category, user: user) }
  let(:channel) { Fabricate(:category_channel, auto_join_users: true, chatable: category) }

  describe "queues batches to automatically add users to a channel" do
    it "queues a batch for users with channel access" do
      assert_batches_enqueued(channel, 1)
    end

    it "does nothing when the channel doesn't exist" do
      assert_batches_enqueued(Chat::Channel.new(id: -1), 0)
    end

    it "does nothing when the chatable is not a category" do
      direct_message = Fabricate(:direct_message)
      channel.update!(chatable: direct_message)

      assert_batches_enqueued(channel, 0)
    end

    it "excludes users not seen in the last 3 months" do
      user.update!(last_seen_at: 3.months.ago)

      assert_batches_enqueued(channel, 0)
    end

    it "excludes users without chat enabled" do
      user.user_option.update!(chat_enabled: false)

      assert_batches_enqueued(channel, 0)
    end

    it "respects the max_chat_auto_joined_users setting" do
      SiteSetting.max_chat_auto_joined_users = 0

      assert_batches_enqueued(channel, 0)
    end

    it "does nothing when we already reached the max_chat_auto_joined_users limit" do
      SiteSetting.max_chat_auto_joined_users = 1
      user_2 = Fabricate(:user, last_seen_at: 2.minutes.ago)
      Chat::UserChatChannelMembership.create!(
        user: user_2,
        chat_channel: channel,
        following: true,
        join_mode: Chat::UserChatChannelMembership.join_modes[:automatic],
      )

      assert_batches_enqueued(channel, 0)
    end

    it "ignores users that are already channel members" do
      Chat::UserChatChannelMembership.create!(user: user, chat_channel: channel, following: true)

      assert_batches_enqueued(channel, 0)
    end

    it "doesn't queue a batch when the user doesn't follow the channel" do
      Chat::UserChatChannelMembership.create!(user: user, chat_channel: channel, following: false)

      assert_batches_enqueued(channel, 0)
    end

    it "skips non-active users" do
      user.update!(active: false)

      assert_batches_enqueued(channel, 0)
    end

    it "skips suspended users" do
      user.update!(suspended_till: 3.years.from_now)

      assert_batches_enqueued(channel, 0)
    end

    it "skips staged users" do
      user.update!(staged: true)

      assert_batches_enqueued(channel, 0)
    end

    context "when the category has read restricted access" do
      fab!(:chatters_group) { Fabricate(:group) }
      let(:private_category) { Fabricate(:private_category, group: chatters_group) }
      let(:channel) { Fabricate(:chat_channel, auto_join_users: true, chatable: private_category) }

      it "doesn't queue a batch if the user is not a group member" do
        assert_batches_enqueued(channel, 0)
      end

      context "when the user has category access to a group" do
        before { chatters_group.add(user) }

        it "queues a batch" do
          assert_batches_enqueued(channel, 1)
        end
      end
    end

    context "when chatable doesn’t exist anymore" do
      let(:channel) do
        Fabricate(
          :category_channel,
          auto_join_users: true,
          chatable_type: "Category",
          chatable_id: -1,
        )
      end

      it "does nothing" do
        assert_batches_enqueued(channel, 0)
      end
    end
  end

  def assert_batches_enqueued(channel, expected)
    expect { subject.execute(chat_channel_id: channel.id) }.to change(
      Jobs::Chat::AutoJoinChannelBatch.jobs,
      :size,
    ).by(expected)
  end
end
