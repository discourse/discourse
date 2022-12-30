# frozen_string_literal: true

RSpec.describe Jobs::ChatNotifyWatching do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  def listen_for_notifications(user, direct_mentioned_user_ids: [], global_mentions: [], mentioned_group_ids: [])
    MessageBus.track_publish("/chat/notification-alert/#{user.id}") do
      subject.execute(
        chat_message_id: message.id,
        direct_mentioned_user_ids: direct_mentioned_user_ids,
        global_mentions: global_mentions,
        mentioned_group_ids: mentioned_group_ids
      )
    end
  end

  def build_notification_translation(channel)
    if channel.direct_message_channel?
      "discourse_push_notifications.popup.new_direct_chat_message"
    else
      "discourse_push_notifications.popup.new_chat_message"
    end
  end

  def expects_push_notification(sender, receiver, message)
    PostAlerter.expects(:push_notification).with(
      receiver,
      has_entries(
        {
          username: sender.username,
          notification_type: Notification.types[:chat_message],
          post_url: message.chat_channel.relative_url,
          translated_title:
            I18n.t(
              build_notification_translation(message.chat_channel),
              { username: sender.username, channel: message.chat_channel.title(receiver) },
            ),
          tag: Chat::ChatNotifier.push_notification_tag(:message, message.chat_channel.id),
          excerpt: message.message,
        },
      ),
    )
  end

  def assert_notification_alert_is_correct(alert_data, sender, receiver, message)
    expect(alert_data).to include(
      {
        username: sender.username,
        notification_type: Notification.types[:chat_message],
        post_url: message.chat_channel.relative_url,
        translated_title:
          I18n.t(
            build_notification_translation(message.chat_channel),
            { username: sender.username, channel: channel.title(receiver) },
          ),
        tag: Chat::ChatNotifier.push_notification_tag(:message, message.chat_channel.id),
        excerpt: message.message,
      },
    )
  end

  context "when the chat message has mentions" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, user: user2, chat_channel: channel)
    end
    fab!(:message) do
      Fabricate(:chat_message, chat_channel: channel, user: user1, message: "this is a new message")
    end

    before do
      membership.update!(
        desktop_notification_level: UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
        mobile_notification_level: UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
      )
    end

    it "skips the watching notifications if it was mentioned directly" do
      PostAlerter.expects(:push_notification).never

      messages = listen_for_notifications(user2, direct_mentioned_user_ids: [user2.id])

      expect(messages.size).to be_zero
    end

    it "skips the watching notifications if it was mentioned through a group" do
      group.add(user2)
      PostAlerter.expects(:push_notification).never

      messages = listen_for_notifications(user2, mentioned_group_ids: [group.id])

      expect(messages.size).to be_zero
    end

    it "doesn't skip watching notifications if the user is not a member of the mentioned group" do
      PostAlerter.expects(:push_notification).once

      messages = listen_for_notifications(user2, mentioned_group_ids: [group.id])

      expect(messages).to be_present
    end

    it "skips the watching notifications if it was mentioned via @all mention" do
      PostAlerter.expects(:push_notification).never

      messages = listen_for_notifications(user2, global_mentions: ["all"])

      expect(messages.size).to be_zero
    end

    it "doesn't skip the watching notifications on @all and ignoring channel wide mention" do
      user2.user_option.update!(ignore_channel_wide_mention: true)

      expects_push_notification(user1, user2, message)

      messages = listen_for_notifications(user2, global_mentions: ["all"])

      assert_notification_alert_is_correct(messages.first.data, user1, user2, message)
    end

    it "skips the watching notifications if it was mentioned via @here mention" do
      PostAlerter.expects(:push_notification).never

      messages = listen_for_notifications(user2, global_mentions: ["here"])

      expect(messages.size).to be_zero
    end

    it "doesn't skip the watching notifications on @here if the user last seen is more than 5 minutes ago" do
      user2.update!(last_seen_at: 6.minutes.ago)

      expects_push_notification(user1, user2, message)

      messages = listen_for_notifications(user2, global_mentions: ["here"])

      assert_notification_alert_is_correct(messages.first.data, user1, user2, message)
    end

    context "when among the user groups there is a mentioned one" do
      it 'skips the watching notification' do
        group.add(user2)
        another_group = Fabricate(:group)
        another_group.add(user2)

        PostAlerter.expects(:push_notification).never

        messages = listen_for_notifications(user2, mentioned_group_ids: [group.id])

        expect(messages.size).to be_zero
      end
    end
  end

  context "for a category channel" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:membership1) do
      Fabricate(:user_chat_channel_membership, user: user1, chat_channel: channel)
    end
    fab!(:membership2) do
      Fabricate(:user_chat_channel_membership, user: user2, chat_channel: channel)
    end
    fab!(:membership3) do
      Fabricate(:user_chat_channel_membership, user: user3, chat_channel: channel)
    end
    fab!(:message) do
      Fabricate(:chat_message, chat_channel: channel, user: user1, message: "this is a new message")
    end

    before do
      membership2.update!(
        desktop_notification_level: UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
      )
    end

    it "sends a desktop notification" do
      messages = listen_for_notifications(user2)

      assert_notification_alert_is_correct(messages.first.data, user1, user2, message)
    end

    context "when the channel is muted via membership preferences" do
      before { membership2.update!(muted: true) }

      it "does not send a desktop or mobile notification" do
        PostAlerter.expects(:push_notification).never
        messages = listen_for_notifications(user2)
        expect(messages).to be_empty
      end
    end

    context "when mobile_notification_level is always and desktop_notification_level is none" do
      before do
        membership2.update!(
          desktop_notification_level: UserChatChannelMembership::NOTIFICATION_LEVELS[:never],
          mobile_notification_level: UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
        )
      end

      it "only sends a mobile notification" do
        expects_push_notification(user1, user2, message)

        messages = listen_for_notifications(user2)

        expect(messages.length).to be_zero
      end

      context "when the channel is muted via membership preferences" do
        before { membership2.update!(muted: true) }

        it "does not send any notification" do
          PostAlerter.expects(:push_notification).never
          messages = listen_for_notifications(user2)
          expect(messages).to be_empty
        end
      end
    end

    context "when the target user cannot chat" do
      before { SiteSetting.chat_allowed_groups = group.id }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end

    context "when the target user cannot see the chat channel" do
      before { channel.update!(chatable: Fabricate(:private_category, group: group)) }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end

    context "when the target user has seen the message already" do
      before { membership2.update!(last_read_message_id: message.id) }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end

    context "when the target user is online via presence channel" do
      before { PresenceChannel.any_instance.expects(:user_ids).returns([user2.id]) }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end

    context "when the target user is suspended" do
      before { user2.update!(suspended_till: 1.year.from_now) }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end
  end

  context "for a direct message channel" do
    fab!(:channel) do
      Fabricate(:direct_message_channel, users: [user1, user2, user3], with_membership: false)
    end
    fab!(:membership1) do
      Fabricate(:user_chat_channel_membership, user: user1, chat_channel: channel)
    end
    fab!(:membership2) do
      Fabricate(:user_chat_channel_membership, user: user2, chat_channel: channel)
    end
    fab!(:membership3) do
      Fabricate(:user_chat_channel_membership, user: user3, chat_channel: channel)
    end
    fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: user1) }

    before do
      membership2.update!(
        desktop_notification_level: UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
      )
    end

    it "sends a desktop notification" do
      messages = listen_for_notifications(user2)

      assert_notification_alert_is_correct(messages.first.data, user1, user2, message)
    end

    context "when the channel is muted via membership preferences" do
      before { membership2.update!(muted: true) }

      it "does not send a desktop or mobile notification" do
        PostAlerter.expects(:push_notification).never

        messages = listen_for_notifications(user2)

        expect(messages).to be_empty
      end
    end

    context "when mobile_notification_level is always and desktop_notification_level is none" do
      before do
        membership2.update!(
          desktop_notification_level: UserChatChannelMembership::NOTIFICATION_LEVELS[:never],
          mobile_notification_level: UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
        )
      end

      it "sends a mobile notification" do
        expects_push_notification(user1, user2, message)

        messages = listen_for_notifications(user2)

        expect(messages.length).to be_zero
      end

      context "when the channel is muted via membership preferences" do
        before { membership2.update!(muted: true) }

        it "does not send a desktop or mobile notification" do
          PostAlerter.expects(:push_notification).never

          messages = listen_for_notifications(user2)

          expect(messages).to be_empty
        end
      end
    end

    context "when the target user cannot chat" do
      before { SiteSetting.chat_allowed_groups = group.id }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end

    context "when the target user cannot see the chat channel" do
      before { membership2.destroy! }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end

    context "when the target user has seen the message already" do
      before { membership2.update!(last_read_message_id: message.id) }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end

    context "when the target user is online via presence channel" do
      before { PresenceChannel.any_instance.expects(:user_ids).returns([user2.id]) }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end

    context "when the target user is suspended" do
      before { user2.update!(suspended_till: 1.year.from_now) }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end

    context "when the target user is preventing communication from the message creator" do
      before { UserCommScreener.any_instance.expects(:allowing_actor_communication).returns([]) }

      it "does not send a desktop notification" do
        expect(listen_for_notifications(user2).count).to be_zero
      end
    end
  end
end
