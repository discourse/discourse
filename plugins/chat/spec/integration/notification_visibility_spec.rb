# frozen_string_literal: true

RSpec.describe "Chat notification visibility" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:category) { Fabricate(:private_category, group:) }
  fab!(:channel) { Fabricate(:category_channel, chatable: category) }
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }
  fab!(:thread) { Fabricate(:chat_thread, channel:, original_message: message) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    group.add(user)
  end

  def notify(type, recipient: user, **data)
    Fabricate(
      :notification,
      user: recipient,
      topic: nil,
      notification_type: Notification.types[type],
      data: data.to_json,
    )
  end

  def visible_notifications(recipient: user)
    Notification::Feed.new(User.find(recipient.id)).notifications
  end

  it "hides mentions, invitations and watched thread notifications when the user loses their channel" do
    notifications =
      %i[chat_mention chat_invitation chat_watched_thread].map do |type|
        notify(
          type,
          chat_channel_id: channel.id,
          chat_message_id: message.id,
          chat_thread_id: thread.id,
        )
      end

    expect(visible_notifications).to match_array(notifications)

    group.remove(user)

    expect(visible_notifications).to be_empty
  end

  describe "watched thread notifications" do
    def notify_watched_thread(recipient: user)
      notify(
        :chat_watched_thread,
        recipient:,
        chat_channel_id: channel.id,
        chat_message_id: message.id,
        chat_thread_id: thread.id,
      )
    end

    it "hides them when the original message is trashed without cleanup" do
      notification = notify_watched_thread

      expect(visible_notifications).to contain_exactly(notification)

      message.trash!

      expect(visible_notifications).to be_empty
    end

    it "hides them when the original message is destroyed" do
      notify_watched_thread
      Chat::Message.where(id: message.id).delete_all

      expect(visible_notifications).to be_empty
    end

    it "hides them when the thread is destroyed" do
      notify_watched_thread
      Chat::Thread.where(id: thread.id).delete_all

      expect(visible_notifications).to be_empty
    end

    it "keeps them for a moderator when the original message is trashed" do
      moderator = Fabricate(:moderator, refresh_auto_groups: true)
      group.add(moderator)
      notification = notify_watched_thread(recipient: moderator)
      message.trash!

      expect(visible_notifications(recipient: moderator)).to contain_exactly(notification)
    end

    it "keeps them for a category group moderator when the original message is trashed" do
      SiteSetting.enable_category_group_moderation = true
      Fabricate(:category_moderation_group, category:, group:)
      notification = notify_watched_thread
      message.trash!

      expect(visible_notifications).to contain_exactly(notification)
    end
  end

  it "hides chat notifications when chat is disabled" do
    notify(:chat_mention, chat_channel_id: channel.id, chat_message_id: message.id)
    SiteSetting.chat_enabled = false

    expect(visible_notifications).to be_empty
  end

  it "hides chat notifications from an admin viewer who cannot see the channel's category" do
    SiteSetting.suppress_secured_categories_from_admin = true
    notify(
      :chat_watched_thread,
      chat_channel_id: channel.id,
      chat_message_id: message.id,
      chat_thread_id: thread.id,
    )
    viewer = Fabricate(:admin, refresh_auto_groups: true)

    expect(Notification::Feed.new(user, viewer: viewer.guardian).notifications).to be_empty
  end
end
