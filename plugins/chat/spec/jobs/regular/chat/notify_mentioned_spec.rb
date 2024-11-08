# frozen_string_literal: true

describe Jobs::Chat::NotifyMentioned do
  subject(:job) { described_class.new }

  fab!(:user_1) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:public_channel) { Fabricate(:category_channel) }

  before do
    user_1.reload
    user_2.reload

    @chat_group = Fabricate(:group, users: [user_1, user_2])
    result =
      Chat::CreateDirectMessageChannel.call(
        guardian: user_1.guardian,
        params: {
          target_usernames: [user_1.username, user_2.username],
        },
      )

    service_failed!(result) if result.failure?

    @personal_chat_channel = result.channel

    [user_1, user_2].each do |u|
      Fabricate(:user_chat_channel_membership, chat_channel: public_channel, user: u)
    end
  end

  def create_chat_message(
    channel: public_channel,
    author: user_1,
    mentioned_user: user_2,
    thread: nil
  )
    message =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: author,
        created_at: 10.minutes.ago,
        thread: thread,
      )
    Fabricate(:user_chat_mention, chat_message: message, user: mentioned_user)
    message
  end

  def track_desktop_notification(
    user: user_2,
    message:,
    to_notify_ids_map:,
    already_notified_user_ids: []
  )
    MessageBus
      .track_publish("/chat/notification-alert/#{user.id}") do
        job.execute(
          chat_message_id: message.id,
          timestamp: message.created_at.to_s,
          to_notify_ids_map: to_notify_ids_map,
          already_notified_user_ids: already_notified_user_ids,
        )
      end
      .first
  end

  def track_core_notification(user: user_2, message:, to_notify_ids_map:)
    job.execute(
      chat_message_id: message.id,
      timestamp: message.created_at.to_s,
      to_notify_ids_map: to_notify_ids_map,
    )

    Notification.where(user: user, notification_type: Notification.types[:chat_mention]).last
  end

  describe "scenarios where we should skip sending notifications" do
    let(:to_notify_ids_map) { { here_mentions: [user_2.id] } }

    it "does nothing if there is a newer version of the message" do
      message = create_chat_message
      Fabricate(:chat_message_revision, chat_message: message, old_message: "a", new_message: "b")

      PostAlerter.expects(:push_notification).never

      desktop_notification =
        track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)
      expect(desktop_notification).to be_nil

      created_notification =
        Notification.where(user: user_2, notification_type: Notification.types[:chat_mention]).last
      expect(created_notification).to be_nil
    end

    it "does nothing when user is not following the channel" do
      message = create_chat_message

      Chat::UserChatChannelMembership.where(chat_channel: public_channel, user: user_2).update!(
        following: false,
      )

      PostAlerter.expects(:push_notification).never

      desktop_notification =
        track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)
      expect(desktop_notification).to be_nil

      created_notification =
        Notification.where(user: user_2, notification_type: Notification.types[:chat_mention]).last
      expect(created_notification).to be_nil
    end

    it "does nothing when user doesn't have a membership record" do
      message = create_chat_message

      Chat::UserChatChannelMembership.find_by(chat_channel: public_channel, user: user_2).destroy!

      PostAlerter.expects(:push_notification).never

      desktop_notification =
        track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)
      expect(desktop_notification).to be_nil

      created_notification =
        Notification.where(user: user_2, notification_type: Notification.types[:chat_mention]).last
      expect(created_notification).to be_nil
    end

    it "does nothing if user is included in the already_notified_user_ids" do
      message = create_chat_message

      PostAlerter.expects(:push_notification).never

      desktop_notification =
        track_desktop_notification(
          message: message,
          to_notify_ids_map: to_notify_ids_map,
          already_notified_user_ids: [user_2.id],
        )
      expect(desktop_notification).to be_nil

      created_notification =
        Notification.where(user: user_2, notification_type: Notification.types[:chat_mention]).last
      expect(created_notification).to be_nil
    end

    it "does nothing if user is not participating in a private channel" do
      user_3 = Fabricate(:user)
      @chat_group.add(user_3)
      to_notify_map = { direct_mentions: [user_3.id] }

      message = create_chat_message(channel: @personal_chat_channel)

      PostAlerter.expects(:push_notification).never

      desktop_notification =
        track_desktop_notification(message: message, to_notify_ids_map: to_notify_map)
      expect(desktop_notification).to be_nil

      created_notification =
        Notification.where(user: user_3, notification_type: Notification.types[:chat_mention]).last
      expect(created_notification).to be_nil
    end

    it "skips desktop notifications based on user preferences" do
      message = create_chat_message
      Chat::UserChatChannelMembership.find_by(chat_channel: public_channel, user: user_2).update!(
        notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:never],
      )

      desktop_notification =
        track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

      expect(desktop_notification).to be_nil
    end

    it "skips push notifications based on user preferences" do
      message = create_chat_message
      Chat::UserChatChannelMembership.find_by(chat_channel: public_channel, user: user_2).update!(
        notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:never],
      )

      PostAlerter.expects(:push_notification).never

      job.execute(
        chat_message_id: message.id,
        timestamp: message.created_at.to_s,
        to_notify_ids_map: to_notify_ids_map,
      )
    end

    it "skips desktop notifications based on user muting preferences" do
      message = create_chat_message
      Chat::UserChatChannelMembership.find_by(chat_channel: public_channel, user: user_2).update!(
        notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
        muted: true,
      )

      desktop_notification =
        track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

      expect(desktop_notification).to be_nil
    end

    it "skips push notifications based on user muting preferences" do
      message = create_chat_message
      Chat::UserChatChannelMembership.find_by(chat_channel: public_channel, user: user_2).update!(
        notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
        muted: true,
      )

      PostAlerter.expects(:push_notification).never

      job.execute(
        chat_message_id: message.id,
        timestamp: message.created_at.to_s,
        to_notify_ids_map: to_notify_ids_map,
      )
    end
  end

  shared_examples "creates different notifications with basic data" do
    let(:expected_channel_title) { public_channel.title(user_2) }

    it "works for desktop notifications" do
      message = create_chat_message
      Fabricate(:all_chat_mention, chat_message: message)
      Fabricate(:here_chat_mention, chat_message: message)
      Fabricate(:group_chat_mention, group: @chat_group, chat_message: message)

      desktop_notification =
        track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

      expect(desktop_notification).to be_present
      expect(desktop_notification.data[:notification_type]).to eq(Notification.types[:chat_mention])
      expect(desktop_notification.data[:username]).to eq(user_1.username)
      expect(desktop_notification.data[:tag]).to eq(
        Chat::Notifier.push_notification_tag(:mention, public_channel.id),
      )
      expect(desktop_notification.data[:excerpt]).to eq(message.push_notification_excerpt)
      expect(desktop_notification.data[:post_url]).to eq(
        "/chat/c/#{public_channel.slug}/#{public_channel.id}/#{message.id}",
      )
    end

    it "works for push notifications" do
      message = create_chat_message
      Fabricate(:all_chat_mention, chat_message: message)
      Fabricate(:here_chat_mention, chat_message: message)
      Fabricate(:group_chat_mention, group: @chat_group, chat_message: message)

      PostAlerter.expects(:push_notification).with(
        user_2,
        {
          notification_type: Notification.types[:chat_mention],
          username: user_1.username,
          tag: Chat::Notifier.push_notification_tag(:mention, public_channel.id),
          excerpt: message.push_notification_excerpt,
          post_url: "/chat/c/#{public_channel.slug}/#{public_channel.id}/#{message.id}",
          translated_title: payload_translated_title,
          channel_id: public_channel.id,
          is_direct_message_channel: false,
        },
      )

      job.execute(
        chat_message_id: message.id,
        timestamp: message.created_at.to_s,
        to_notify_ids_map: to_notify_ids_map,
      )
    end

    it "works for core notifications" do
      message = create_chat_message
      Fabricate(:all_chat_mention, chat_message: message)
      Fabricate(:here_chat_mention, chat_message: message)
      Fabricate(:group_chat_mention, group: @chat_group, chat_message: message)

      created_notification =
        track_core_notification(message: message, to_notify_ids_map: to_notify_ids_map)

      expect(created_notification).to be_present
      expect(created_notification.high_priority).to eq(true)
      expect(created_notification.read).to eq(false)

      data_hash = created_notification.data_hash

      expect(data_hash[:chat_message_id]).to eq(message.id)
      expect(data_hash[:chat_channel_id]).to eq(public_channel.id)
      expect(data_hash[:mentioned_by_username]).to eq(user_1.username)
      expect(data_hash[:is_direct_message_channel]).to eq(false)
      expect(data_hash[:chat_channel_title]).to eq(expected_channel_title)
      expect(data_hash[:chat_channel_slug]).to eq(public_channel.slug)
    end
  end

  describe "#execute" do
    describe "global mention notifications" do
      let(:to_notify_ids_map) { { global_mentions: [user_2.id] } }

      let(:payload_translated_title) do
        I18n.t(
          "discourse_push_notifications.popup.chat_mention.other_type",
          username: user_1.username,
          identifier: "@all",
          channel: public_channel.title(user_2),
        )
      end

      include_examples "creates different notifications with basic data"

      it "includes global mention specific data to core notifications" do
        message = create_chat_message
        Fabricate(:all_chat_mention, chat_message: message)

        created_notification =
          track_core_notification(message: message, to_notify_ids_map: to_notify_ids_map)

        data_hash = created_notification.data_hash

        expect(data_hash[:identifier]).to eq("all")
      end

      it "includes global mention specific data to desktop notifications" do
        message = create_chat_message
        Fabricate(:all_chat_mention, chat_message: message)

        desktop_notification =
          track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

        expect(desktop_notification.data[:translated_title]).to eq(payload_translated_title)
      end

      context "with private channels" do
        it "users a different translated title" do
          message = create_chat_message(channel: @personal_chat_channel)
          Fabricate(:all_chat_mention, chat_message: message)

          desktop_notification =
            track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

          expected_title =
            I18n.t(
              "discourse_push_notifications.popup.direct_message_chat_mention.other_type",
              username: user_1.username,
              identifier: "@all",
            )

          expect(desktop_notification.data[:translated_title]).to eq(expected_title)
        end
      end
    end

    describe "here mention notifications" do
      let(:to_notify_ids_map) { { here_mentions: [user_2.id] } }

      let(:payload_translated_title) do
        I18n.t(
          "discourse_push_notifications.popup.chat_mention.other_type",
          username: user_1.username,
          identifier: "@here",
          channel: public_channel.title(user_2),
        )
      end

      include_examples "creates different notifications with basic data"

      it "includes here mention specific data to core notifications" do
        message = create_chat_message
        Fabricate(:here_chat_mention, chat_message: message)

        created_notification =
          track_core_notification(message: message, to_notify_ids_map: to_notify_ids_map)
        data_hash = created_notification.data_hash

        expect(data_hash[:identifier]).to eq("here")
      end

      it "includes here mention specific data to desktop notifications" do
        message = create_chat_message
        Fabricate(:here_chat_mention, chat_message: message)

        desktop_notification =
          track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

        expect(desktop_notification.data[:translated_title]).to eq(payload_translated_title)
      end

      context "with private channels" do
        it "uses a different translated title" do
          message = create_chat_message(channel: @personal_chat_channel)
          Fabricate(:here_chat_mention, chat_message: message)

          desktop_notification =
            track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

          expected_title =
            I18n.t(
              "discourse_push_notifications.popup.direct_message_chat_mention.other_type",
              username: user_1.username,
              identifier: "@here",
            )

          expect(desktop_notification.data[:translated_title]).to eq(expected_title)
        end
      end
    end

    describe "direct mention notifications" do
      let(:to_notify_ids_map) { { direct_mentions: [user_2.id] } }

      let(:payload_translated_title) do
        I18n.t(
          "discourse_push_notifications.popup.chat_mention.direct",
          username: user_1.username,
          identifier: "",
          channel: public_channel.title(user_2),
        )
      end

      include_examples "creates different notifications with basic data"

      it "includes here mention specific data to core notifications" do
        message = create_chat_message

        created_notification =
          track_core_notification(message: message, to_notify_ids_map: to_notify_ids_map)
        data_hash = created_notification.data_hash

        expect(data_hash[:identifier]).to be_nil
      end

      it "includes here mention specific data to desktop notifications" do
        message = create_chat_message

        desktop_notification =
          track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

        expect(desktop_notification.data[:translated_title]).to eq(payload_translated_title)
      end

      context "when the mention is within a thread" do
        before { public_channel.update!(threading_enabled: true) }

        fab!(:thread) { Fabricate(:chat_thread, channel: public_channel) }

        it "uses the thread URL for the post_url in the desktop notification" do
          message = create_chat_message(thread: thread)
          desktop_notification =
            track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)
          expect(desktop_notification.data[:post_url]).to eq(thread.relative_url)
        end

        it "includes the thread ID in the core notification data" do
          message = create_chat_message(thread: thread)
          created_notification =
            track_core_notification(message: message, to_notify_ids_map: to_notify_ids_map)
          expect(created_notification.data_hash[:chat_thread_id]).to eq(thread.id)
        end
      end

      context "with private channels" do
        it "users a different translated title" do
          message = create_chat_message(channel: @personal_chat_channel)

          desktop_notification =
            track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

          expected_title =
            I18n.t(
              "discourse_push_notifications.popup.direct_message_chat_mention.direct",
              username: user_1.username,
              identifier: "",
            )

          expect(desktop_notification.data[:translated_title]).to eq(expected_title)
        end
      end
    end

    describe "group mentions" do
      let(:to_notify_ids_map) { { @chat_group.name.to_sym => [user_2.id] } }

      let(:payload_translated_title) do
        I18n.t(
          "discourse_push_notifications.popup.chat_mention.other_type",
          username: user_1.username,
          identifier: "@#{@chat_group.name}",
          channel: public_channel.title(user_2),
        )
      end

      include_examples "creates different notifications with basic data"

      it "includes here mention specific data to core notifications" do
        message = create_chat_message
        Fabricate(:group_chat_mention, group: @chat_group, chat_message: message)

        created_notification =
          track_core_notification(message: message, to_notify_ids_map: to_notify_ids_map)
        data_hash = created_notification.data_hash

        expect(data_hash[:identifier]).to eq(@chat_group.name)
        expect(data_hash[:is_group_mention]).to eq(true)
      end

      it "includes here mention specific data to desktop notifications" do
        message = create_chat_message
        Fabricate(:group_chat_mention, group: @chat_group, chat_message: message)

        desktop_notification =
          track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

        expect(desktop_notification.data[:translated_title]).to eq(payload_translated_title)
      end

      context "with private channels" do
        it "uses a different translated title" do
          message = create_chat_message(channel: @personal_chat_channel)
          Fabricate(:group_chat_mention, group: @chat_group, chat_message: message)

          desktop_notification =
            track_desktop_notification(message: message, to_notify_ids_map: to_notify_ids_map)

          expected_title =
            I18n.t(
              "discourse_push_notifications.popup.direct_message_chat_mention.other_type",
              username: user_1.username,
              identifier: "@#{@chat_group.name}",
            )

          expect(desktop_notification.data[:translated_title]).to eq(expected_title)
        end
      end
    end
  end
end
