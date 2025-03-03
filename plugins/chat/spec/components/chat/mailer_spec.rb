# frozen_string_literal: true

describe Chat::Mailer do
  fab!(:user) { Fabricate(:user, last_seen_at: 1.hour.ago) }
  fab!(:other) { Fabricate(:user) }

  fab!(:group) do
    Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone], users: [user, other])
  end

  fab!(:followed_channel) { Fabricate(:category_channel) }
  fab!(:non_followed_channel) { Fabricate(:category_channel) }
  fab!(:muted_channel) { Fabricate(:category_channel) }
  fab!(:unseen_channel) { Fabricate(:category_channel) }
  fab!(:direct_message) { Fabricate(:direct_message_channel, users: [user, other]) }

  fab!(:job) { :user_email }
  fab!(:args) { { type: :chat_summary, user_id: user.id, force_respect_seen_recently: true } }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  def expect_enqueued
    expect {
      expect_enqueued_with(job:, args:) { described_class.send_unread_mentions_summary }
    }.to_not output.to_stderr_from_any_process
    expect(Jobs::UserEmail.jobs.size).to eq(1)
  end

  def expect_not_enqueued
    expect_not_enqueued_with(job:, args:) { described_class.send_unread_mentions_summary }
  end

  # This helper is much faster than `Fabricate(:chat_message_with_service, ...)`
  def create_message(chat_channel, message, mention_klass = nil)
    chat_message = Fabricate(:chat_message, user: other, chat_channel:, message:)

    if mention_klass
      notification_type = Notification.types[:chat_mention]

      Fabricate(
        :chat_mention_notification,
        notification: Fabricate(:notification, user:, notification_type:),
        chat_mention: mention_klass.find_by(chat_message:),
      )
    end

    chat_message
  end

  describe "in a followed channel" do
    before { followed_channel.add(user) }

    describe "there is a new message" do
      let!(:chat_message) { create_message(followed_channel, "hello y'all :wave:") }

      it "does not queue a chat summary" do
        expect_not_enqueued
      end
    end

    describe "user is @direct mentioned" do
      let!(:chat_message) do
        create_message(followed_channel, "hello @#{user.username}", Chat::UserMention)
      end

      it "queues a chat summary email" do
        expect_enqueued
      end

      it "does not queue a chat summary when chat is globally disabled" do
        SiteSetting.chat_enabled = false
        expect_not_enqueued
      end

      it "does not queue a chat summary email when user has chat disabled" do
        user.user_option.update!(chat_enabled: false)
        expect_not_enqueued
      end

      it "does not queue a chat summary email when user has chat email frequency = never" do
        user.user_option.update!(chat_email_frequency: UserOption.chat_email_frequencies[:never])
        expect_not_enqueued
      end

      it "does not queue a chat summary email when user has email level = never" do
        user.user_option.update!(email_level: UserOption.email_level_types[:never])
        expect_not_enqueued
      end

      it "does not queue a chat summary email when chat message has been deleted" do
        chat_message.trash!
        expect_not_enqueued
      end

      it "does not queue a chat summary email when chat message is older than 1 week" do
        chat_message.update!(created_at: 2.weeks.ago)
        expect_not_enqueued
      end

      it "does not queue a chat summary email when chat channel has been deleted" do
        followed_channel.trash!
        expect_not_enqueued
      end

      it "does not queue a chat summary email when user is not part of chat allowed groups" do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:admins]
        expect_not_enqueued
      end

      it "does not queue a chat summary email when user has read the mention notification" do
        Notification.find_by(
          user: user,
          notification_type: Notification.types[:chat_mention],
        ).update!(read: true)

        expect_not_enqueued
      end

      it "does not queue a chat summary email when user has been seen in the past 15 minutes" do
        user.update!(last_seen_at: 5.minutes.ago)
        expect_not_enqueued
      end

      it "does not queue a chat summary email when user has read the message" do
        followed_channel.membership_for(user).update!(last_read_message_id: chat_message.id)
        expect_not_enqueued
      end

      it "does not queue a chat summary email when user has received an email for this message" do
        followed_channel.membership_for(user).update!(
          last_unread_mention_when_emailed_id: chat_message.id,
        )

        expect_not_enqueued
      end

      it "does not queue a chat summary email when user is not active" do
        user.update!(active: false)
        expect_not_enqueued
      end

      it "does not queue a chat summary email when user is staged" do
        user.update!(staged: true)
        expect_not_enqueued
      end

      it "does not queue a chat summary email when user is suspended" do
        user.update!(suspended_till: 1.day.from_now)
        expect_not_enqueued
      end

      it "does not queue a chat summary email when sender has been deleted" do
        other.destroy!
        expect_not_enqueued
      end

      it "does not queue a chat summary email when chat message was created by the SDK" do
        chat_message.update!(created_by_sdk: true)
        expect_not_enqueued
      end

      it "queues a chat summary email even when user has private messages disabled" do
        user.user_option.update!(allow_private_messages: false)
        expect_enqueued
      end

      describe "when another plugin blocks the email" do
        let!(:plugin) { Plugin::Instance.new }
        let!(:modifier) { :chat_mailer_send_summary_to_user }
        let!(:block) { Proc.new { false } }

        before { DiscoursePluginRegistry.register_modifier(plugin, modifier, &block) }
        after { DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &block) }

        it "does not queue a chat summary email" do
          expect_not_enqueued
        end
      end
    end

    describe "user is @group mentioned" do
      before { create_message(followed_channel, "hello @#{group.name}", Chat::GroupMention) }

      it "queues a chat summary email" do
        expect_enqueued
      end
    end

    describe "user is @all mentioned" do
      before { create_message(followed_channel, "hello @all", Chat::AllMention) }

      it "queues a chat summary email" do
        expect_enqueued
      end
    end
  end

  describe "in a non-followed channel" do
    before { non_followed_channel.add(user).update!(following: false) }

    describe "there is a new message" do
      let!(:chat_message) { create_message(non_followed_channel, "hello y'all :wave:") }

      it "does not queue a chat summary" do
        expect_not_enqueued
      end
    end

    describe "user is @direct mentioned" do
      before { create_message(non_followed_channel, "hello @#{user.username}", Chat::UserMention) }

      it "does not queue a chat summary email" do
        expect_not_enqueued
      end
    end

    describe "user is @group mentioned" do
      before { create_message(non_followed_channel, "hello @#{group.name}", Chat::GroupMention) }

      it "does not queue a chat summary email" do
        expect_not_enqueued
      end
    end

    describe "user is @all mentioned" do
      before { create_message(non_followed_channel, "hello @all", Chat::AllMention) }

      it "does not queue a chat summary email" do
        expect_not_enqueued
      end
    end
  end

  describe "in a muted channel" do
    before { muted_channel.add(user).update!(muted: true) }

    describe "there is a new message" do
      let!(:chat_message) { create_message(muted_channel, "hello y'all :wave:") }

      it "does not queue a chat summary" do
        expect_not_enqueued
      end
    end

    describe "user is @direct mentioned" do
      before { create_message(muted_channel, "hello @#{user.username}", Chat::UserMention) }

      it "does not queue a chat summary email" do
        expect_not_enqueued
      end
    end

    describe "user is @group mentioned" do
      before { create_message(muted_channel, "hello @#{group.name}", Chat::GroupMention) }

      it "does not queue a chat summary email" do
        expect_not_enqueued
      end
    end

    describe "user is @all mentioned" do
      before { create_message(muted_channel, "hello @all", Chat::AllMention) }

      it "does not queue a chat summary email" do
        expect_not_enqueued
      end
    end
  end

  describe "in an unseen channel" do
    describe "there is a new message" do
      let!(:chat_message) { create_message(unseen_channel, "hello y'all :wave:") }

      it "does not queue a chat summary" do
        expect_not_enqueued
      end
    end

    describe "user is @direct mentioned" do
      before { create_message(unseen_channel, "hello @#{user.username}") }

      it "does not queue a chat summary email" do
        expect_not_enqueued
      end
    end

    describe "user is @group mentioned" do
      before { create_message(unseen_channel, "hello @#{group.name}") }

      it "doest not queue a chat summary email" do
        expect_not_enqueued
      end
    end

    describe "there is an @all mention" do
      before { create_message(unseen_channel, "hello @all", Chat::AllMention) }

      it "does not queue a chat summary email" do
        expect_not_enqueued
      end
    end
  end

  describe "in a direct message" do
    before { create_message(direct_message, "Howdy 👋") }

    it "queues a chat summary email" do
      expect_enqueued
    end

    it "queues a chat summary email even when user isn't following the direct message anymore" do
      direct_message.membership_for(user).update!(following: false)
      expect_enqueued
    end

    it "does not queue a chat summary email when user has muted the direct message" do
      direct_message.membership_for(user).update!(muted: true)
      expect_not_enqueued
    end

    it "does not queue a chat summary email when user has private messages disabled" do
      user.user_option.update!(allow_private_messages: false)
      expect_not_enqueued
    end

    it "queues a chat summary email when message is the original thread message" do
      Fabricate(:chat_thread, channel: direct_message, original_message: Chat::Message.last)
      expect_enqueued
    end
  end

  describe "in direct message channel with threads" do
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, other]) }
    fab!(:message) do
      Fabricate(:chat_message, chat_channel: dm_channel, user: other, created_at: 2.weeks.ago)
    end
    fab!(:thread) do
      Fabricate(:chat_thread, channel: dm_channel, original_message: message, with_replies: 1)
    end

    it "does not queue a chat summary email for thread replies" do
      expect_not_enqueued
    end

    it "queues a chat summary email when user is watching the thread" do
      Fabricate(
        :user_chat_thread_membership,
        user: user,
        thread: thread,
        notification_level: Chat::NotificationLevels.all[:watching],
      )

      expect_enqueued
    end

    it "does not queue a chat summary for threads watched by other users" do
      thread.membership_for(other).update!(
        notification_level: Chat::NotificationLevels.all[:watching],
      )

      expect_not_enqueued
    end
  end
end
