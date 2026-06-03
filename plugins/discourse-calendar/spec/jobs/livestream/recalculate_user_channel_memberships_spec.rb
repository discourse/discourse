# frozen_string_literal: true

RSpec.describe Jobs::LivestreamRecalculateUserChannelMemberships do
  def run_job
    Jobs::LivestreamRecalculateUserChannelMemberships.new.execute
  end

  fab!(:admin)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }

  fab!(:livestream_channel1, :category_channel)
  fab!(:livestream_channel2, :category_channel)

  fab!(:normal_channel1, :category_channel)
  fab!(:normal_channel2, :category_channel)

  fab!(:topic1) { Fabricate(:topic, user: user) }
  fab!(:topic2) { Fabricate(:topic, user: user) }

  fab!(:topic_chat_channel1) do
    Fabricate(:topic_chat_channel, topic: topic1, chat_channel: livestream_channel1)
  end
  fab!(:topic_chat_channel2) do
    Fabricate(:topic_chat_channel, topic: topic2, chat_channel: livestream_channel2)
  end

  fab!(:first_post1) { Fabricate(:post, topic: topic1) }
  fab!(:first_post2) { Fabricate(:post, topic: topic2) }

  fab!(:normal_membership1) do
    Fabricate(
      :user_chat_channel_membership,
      user: user,
      chat_channel: normal_channel1,
      following: true,
    )
  end

  fab!(:normal_membership2) do
    Fabricate(
      :user_chat_channel_membership,
      user: user,
      chat_channel: normal_channel2,
      following: false,
    )
  end

  fab!(:event1) do
    Fabricate(
      :event,
      post: first_post1,
      original_starts_at: Time.now + 1.hour,
      original_ends_at: Time.now + 2.hours,
    )
  end

  fab!(:event2) do
    Fabricate(
      :event,
      post: first_post2,
      original_starts_at: Time.now + 1.hour,
      original_ends_at: Time.now + 2.hours,
    )
  end

  fab!(:livestream_membership1) do
    Fabricate(:user_chat_channel_membership, user: user, chat_channel: livestream_channel1)
  end

  fab!(:livestream_membership2) do
    Fabricate(:user_chat_channel_membership, user: user, chat_channel: livestream_channel2)
  end

  fab!(:post_event_invitee1) do
    Fabricate(
      :post_event_invitee,
      event: event1,
      user: user,
      status: DiscoursePostEvent::Invitee.statuses[:going],
    )
  end

  fab!(:post_event_invitee2) do
    Fabricate(
      :post_event_invitee,
      event: event2,
      user: user,
      status: DiscoursePostEvent::Invitee.statuses[:going],
    )
  end
  before do
    SiteSetting.livestream_enabled = true
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe "when user is not in the allow list" do
    before { SiteSetting.livestream_chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_4].to_s }

    it "unfollows all livestream channels" do
      run_job

      expect(livestream_membership1.following).to eq(false)
      expect(livestream_membership2.following).to eq(false)
      expect(normal_membership1.following).to eq(true)
      expect(normal_membership2.following).to eq(false)
      expect(Chat::UserChatChannelMembership.count).to eq(4)
    end

    it "publishes membership changes only to the affected user's message bus channel" do
      messages = MessageBus.track_publish { run_job }

      expect(messages).not_to be_empty
      expect(messages).to all(
        have_attributes(
          channel: "/discourse-calendar/livestream/chat-status/#{user.id}",
          user_ids: [user.id],
        ),
      )
    end
  end
end
