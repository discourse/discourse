# frozen_string_literal: true

describe UserNotifications do
  fab!(:user) { Fabricate(:user, last_seen_at: 1.hour.ago) }
  fab!(:other) { Fabricate(:user) }
  fab!(:another) { Fabricate(:user) }
  fab!(:someone) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group, users: [user, other]) }

  fab!(:followed_channel) { Fabricate(:category_channel) }
  fab!(:followed_channel_2) { Fabricate(:category_channel) }
  fab!(:followed_channel_3) { Fabricate(:category_channel) }
  fab!(:non_followed_channel) { Fabricate(:category_channel) }
  fab!(:muted_channel) { Fabricate(:category_channel) }
  fab!(:unseen_channel) { Fabricate(:category_channel) }
  fab!(:private_channel) { Fabricate(:private_category_channel, group:) }
  fab!(:direct_message) { Fabricate(:direct_message_channel, users: [user, other]) }
  fab!(:direct_message_2) { Fabricate(:direct_message_channel, users: [user, another]) }
  fab!(:direct_message_3) { Fabricate(:direct_message_channel, users: [user, someone]) }
  fab!(:group_message) { Fabricate(:direct_message_channel, users: [user, other, another]) }

  fab!(:site_name) { SiteSetting.email_prefix.presence || SiteSetting.title }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

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

  def no_chat_summary_email
    email = described_class.chat_summary(user, {})
    expect(email.to).to be_blank
  end

  def chat_summary_email
    email = described_class.chat_summary(user, {})
    expect(email.to).to contain_exactly(user.email)
    email
  end

  def chat_summary_with_subject(type, opts = {})
    expect(chat_summary_email.subject).to eq(
      I18n.t("user_notifications.chat_summary.subject.#{type}", { site_name:, **opts }),
    )
  end

  describe "in a followed channel" do
    before { followed_channel.add(user) }

    describe "user is mentioned" do
      let!(:chat_mention) do
        create_message(followed_channel, "hello @#{user.username}", Chat::UserMention)
      end

      it "sends a chat summary email" do
        chat_summary_with_subject(:chat_channel_1, channel: followed_channel.name, count: 1)
      end

      it "pluralizes the subject" do
        create_message(followed_channel, "how are you?")
        chat_summary_with_subject(:chat_channel_1, channel: followed_channel.name, count: 2)
      end

      it "sends a chat summary email with correct body" do
        html = chat_summary_email.html_part.body.to_s

        expect(html).to include(followed_channel.title(user))
        expect(html).to include(chat_mention.full_url)
        expect(html).to include(PrettyText.format_for_email(chat_mention.cooked_for_excerpt))
        expect(html).to include(chat_mention.user.small_avatar_url)
        expect(html).to include(chat_mention.user.username)
        expect(html).to include(
          I18n.l(UserOption.user_tzinfo(user.id).to_local(chat_mention.created_at), format: :long),
        )
        expect(html).to include(I18n.t("user_notifications.chat_summary.view_messages", count: 1))
      end

      it "sends a chat summary email with view more link" do
        create_message(followed_channel, "how are you...")
        create_message(followed_channel, "doing...")
        create_message(followed_channel, "today?")

        html = chat_summary_email.html_part.body.to_s

        expect(html).to include(I18n.t("user_notifications.chat_summary.view_more", count: 2))
      end

      describe "SiteSetting.prioritize_username_in_ux is disabled" do
        before { SiteSetting.prioritize_username_in_ux = false }

        it "sends a chat summary email with the username instead of the name" do
          html = chat_summary_email.html_part.body.to_s

          expect(html).to include(chat_mention.user.name)
          expect(html).not_to include(chat_mention.user.username)
        end
      end

      describe "when using subfolder" do
        before { set_subfolder "/community" }

        it "sends a chat summary email with the correct URL" do
          html = chat_summary_email.html_part.body.to_s

          expect(html).to include <<~HTML.strip
            <a class="more-messages-link" href="#{Discourse.base_url}/chat
          HTML
        end
      end

      it "does not send an email if user can't chat" do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:admins]
        no_chat_summary_email
      end

      it "does not send an email if the user has been seen recently" do
        user.update!(last_seen_at: 5.minutes.ago)
        no_chat_summary_email
      end

      it "does not send an email if the user has disabled chat emails" do
        user.user_option.update!(chat_email_frequency: UserOption.chat_email_frequencies[:never])
        no_chat_summary_email
      end

      it "does not send an email if the user has disabled all emails" do
        user.user_option.update!(email_level: UserOption.email_level_types[:never])
        no_chat_summary_email
      end

      it "does not send an email if the channel has been deleted" do
        followed_channel.trash!
        no_chat_summary_email
      end

      it "does not send an email if the chat message has been deleted" do
        chat_mention.trash!
        no_chat_summary_email
      end

      it "does not send an email if the mention is more than a week old" do
        chat_mention.update!(created_at: 10.days.ago)
        no_chat_summary_email
      end

      it "does not send an email if the user isn't following the channel anymore" do
        followed_channel.membership_for(user).update!(following: false)
        no_chat_summary_email
      end

      it "does not send an email if the user has already read the message" do
        followed_channel.membership_for(user).update!(last_read_message_id: chat_mention.id)
        no_chat_summary_email
      end

      it "does not send an email if the user has already received a chat summary email" do
        followed_channel.membership_for(user).update!(
          last_unread_mention_when_emailed_id: chat_mention.id,
        )
        no_chat_summary_email
      end

      it "does not send an email if the user has read the mention notification" do
        Notification.find_by(
          user: user,
          notification_type: Notification.types[:chat_mention],
        ).update!(read: true)

        no_chat_summary_email
      end

      it "does not send an email if the sender has been deleted" do
        other.destroy!
        no_chat_summary_email
      end

      describe "SiteSetting.private_email is enabled" do
        before { SiteSetting.private_email = true }

        it "sends a chat summary email with a private subject" do
          chat_summary_with_subject(:private_email, count: 1)
        end

        it "pluralizes the private subject" do
          create_message(followed_channel, "how are you?")
          chat_summary_with_subject(:private_email, count: 2)
        end

        it "sends a chat summary email with a private body" do
          html = chat_summary_email.html_part.body.to_s

          expect(html).to include(
            I18n.t("system_messages.private_channel_title", id: followed_channel.id),
          )

          expect(html).to include(chat_mention.full_url)
          expect(html).to include(I18n.t("user_notifications.chat_summary.view_messages", count: 1))

          expect(html).not_to include(followed_channel.title(user))
          expect(html).not_to include(PrettyText.format_for_email(chat_mention.cooked_for_excerpt))
          expect(html).not_to include(chat_mention.user.small_avatar_url)
          expect(html).not_to include(chat_mention.user.username)
        end
      end
    end

    describe "user is not mentioned" do
      before { create_message(followed_channel, "hello") }

      it "does not send a chat summary email" do
        no_chat_summary_email
      end
    end

    describe "group is mentioned" do
      before do
        group.update!(mentionable_level: Group::ALIAS_LEVELS[:everyone])
        create_message(followed_channel, "hello @#{group.name}", Chat::GroupMention)
      end

      it "sends a chat summary email" do
        chat_summary_with_subject(:chat_channel_1, channel: followed_channel.name, count: 1)
      end

      describe "when the group is not mentionable" do
        before { group.update!(mentionable_level: Group::ALIAS_LEVELS[:nobody]) }

        it "does not send a chat summary email" do
          no_chat_summary_email
        end
      end
    end

    describe "channel does not allow channel wide mentions" do
      before { followed_channel.update!(allow_channel_wide_mentions: false) }

      it "does not send a chat summary email" do
        create_message(followed_channel, "hello @all", Chat::AllMention)
        no_chat_summary_email
      end
    end
  end

  describe "in two followed channels" do
    before do
      followed_channel.add(user)
      followed_channel_2.add(user)
    end

    describe "user is mentioned in one channel" do
      before do
        create_message(followed_channel, "hello @#{user.username}", Chat::UserMention)
        create_message(followed_channel_2, "hello")
      end

      it "sends a chat summary email" do
        chat_summary_with_subject(:chat_channel_1, channel: followed_channel.name, count: 1)
      end
    end

    describe "user is mentioned in both channels" do
      before do
        create_message(followed_channel, "hello @#{user.username}", Chat::UserMention)
        create_message(followed_channel_2, "hello @#{user.username}", Chat::UserMention)
      end

      it "sends a chat summary email" do
        chat_summary_with_subject(
          :chat_channel_2,
          channel_1: followed_channel.name,
          channel_2: followed_channel_2.name,
        )
      end
    end
  end

  describe "in three followed channels" do
    before do
      followed_channel.add(user)
      followed_channel_2.add(user)
      followed_channel_3.add(user)
    end

    describe "user is mentioned in one channel" do
      before do
        create_message(followed_channel, "hello @#{user.username}", Chat::UserMention)
        create_message(followed_channel_2, "hello")
        create_message(followed_channel_3, "hello")
      end

      it "sends a chat summary email" do
        chat_summary_with_subject(:chat_channel_1, channel: followed_channel.name, count: 1)
      end
    end

    describe "user is mentioned in two channels" do
      before do
        create_message(followed_channel, "hello @#{user.username}", Chat::UserMention)
        create_message(followed_channel_2, "hello @#{user.username}", Chat::UserMention)
        create_message(followed_channel_3, "hello")
      end

      it "sends a chat summary email" do
        chat_summary_with_subject(
          :chat_channel_2,
          channel_1: followed_channel.name,
          channel_2: followed_channel_2.name,
        )
      end
    end

    describe "user is mentioned in all channels" do
      before do
        create_message(followed_channel, "hello @#{user.username}", Chat::UserMention)
        create_message(followed_channel_2, "hello @#{user.username}", Chat::UserMention)
        create_message(followed_channel_3, "hello @#{user.username}", Chat::UserMention)
      end

      it "sends a chat summary email" do
        chat_summary_with_subject(:chat_channel_3_or_more, channel: followed_channel.name, count: 2)
      end
    end
  end

  describe "in a non-followed channel" do
    before { non_followed_channel.add(user).update!(following: false) }

    describe "user is mentioned" do
      before { create_message(non_followed_channel, "hello @#{user.username}", Chat::UserMention) }

      it "does not send a chat summary email" do
        no_chat_summary_email
      end
    end

    describe "user is not mentioned" do
      before { create_message(non_followed_channel, "hello") }

      it "does not send a chat summary email" do
        no_chat_summary_email
      end
    end
  end

  describe "in a muted channel" do
    before { muted_channel.add(user).update!(muted: true) }

    describe "user is mentioned" do
      before { create_message(muted_channel, "hello @#{user.username}", Chat::UserMention) }

      it "does not send a chat summary email" do
        no_chat_summary_email
      end
    end

    describe "user is not mentioned" do
      before { create_message(muted_channel, "hello") }

      it "does not send a chat summary email" do
        no_chat_summary_email
      end
    end
  end

  describe "in an unseen channel" do
    describe "user is mentioned" do
      before { create_message(unseen_channel, "hello @#{user.username}", Chat::UserMention) }

      it "does not send a chat summary email" do
        no_chat_summary_email
      end
    end

    describe "user is not mentioned" do
      before { create_message(unseen_channel, "hello") }

      it "does not send a chat summary email" do
        no_chat_summary_email
      end
    end
  end

  describe "in a private channel" do
    before { private_channel.add(user) }

    describe "user is mentioned" do
      before { create_message(private_channel, "hello @#{user.username}", Chat::UserMention) }

      it "sends a chat summary email" do
        chat_summary_with_subject(:chat_channel_1, channel: private_channel.name, count: 1)
      end

      it "does not send a chat summary email when the user is not member of the group anymore" do
        group.remove(user)
        no_chat_summary_email
      end
    end
  end

  describe "in a 1:1" do
    before { create_message(direct_message, "Hello 👋") }

    it "sends a chat summary email" do
      chat_summary_with_subject(:chat_dm_1, name: direct_message.title(user), count: 1)
    end

    it "pluralizes the subject" do
      create_message(direct_message, "How are you?")
      chat_summary_with_subject(:chat_dm_1, name: direct_message.title(user), count: 2)
    end

    it "does not send an email if the user has disabled private messages" do
      user.user_option.update!(allow_private_messages: false)
      no_chat_summary_email
    end

    it "sends a chat summary email even if the user isn't following the direct message" do
      direct_message.membership_for(user).update!(following: false)
      chat_summary_with_subject(:chat_dm_1, name: direct_message.title(user), count: 1)
    end
  end

  describe "in two 1:1s" do
    before do
      create_message(direct_message, "Hello 👋")
      create_message(direct_message_2, "Hello 👋")
    end

    it "sends a chat summary email" do
      chat_summary_with_subject(
        :chat_dm_2,
        name_1: direct_message.title(user),
        name_2: direct_message_2.title(user),
      )
    end
  end

  describe "in three 1:1s" do
    before do
      create_message(direct_message, "Hello 👋")
      create_message(direct_message_2, "Hello 👋")
      create_message(direct_message_3, "Hello 👋")
    end

    it "sends a chat summary email" do
      chat_summary_with_subject(:chat_dm_3_or_more, name: direct_message.title(user), count: 2)
    end
  end

  describe "in a 1:many" do
    before { create_message(group_message, "Hello 👋") }

    it "sends a chat summary email" do
      chat_summary_with_subject(:chat_channel_1, channel: group_message.title(user), count: 1)
    end

    it "pluralizes the subject" do
      create_message(group_message, "How are you?")
      chat_summary_with_subject(:chat_channel_1, channel: group_message.title(user), count: 2)
    end
  end

  describe "in a followed channel and a 1:1" do
    before { followed_channel.add(user) }

    describe "user is mentioned in the channel and replied in the 1:1" do
      before do
        create_message(followed_channel, "hello @#{user.username}", Chat::UserMention)
        create_message(direct_message, "hello")
      end

      it "sends a chat summary email" do
        chat_summary_with_subject(
          :chat_channel_and_dm,
          channel: followed_channel.name,
          name: direct_message.title(user),
        )
      end
    end

    describe "when another user is mentioned in the channel and user receives a 1:1" do
      before do
        create_message(direct_message, "Hello, how are you?")
        create_message(followed_channel, "Hey @#{another.username}", Chat::UserMention)
      end

      it "does not show the channel mention in the subject" do
        chat_summary_with_subject(:chat_dm_1, name: direct_message.title(user), count: 1)
      end

      it "does not show the channel mention in the body" do
        html = chat_summary_email.html_part.body.to_s

        expect(html).to include(direct_message.title(user))
        expect(html).not_to include(followed_channel.title(user))
      end
    end

    describe "when mentioning @all in the channel and user receives a 1:1" do
      before do
        create_message(direct_message, "Hello, how are you?")
        create_message(followed_channel, "Hey @all", Chat::AllMention)
      end

      it "shows both the channel mention and 1:1 in the subject" do
        chat_summary_with_subject(
          :chat_channel_and_dm,
          channel: followed_channel.name,
          name: direct_message.title(user),
        )
      end

      it "shows both the channel mention and 1:1 in the body" do
        html = chat_summary_email.html_part.body.to_s

        expect(html).to include(direct_message.title(user))
        expect(html).to include(followed_channel.title(user))
      end
    end

    describe "when mentioning a group in the channel and user receives a 1:1" do
      before do
        group.update!(mentionable_level: Group::ALIAS_LEVELS[:everyone])
        create_message(direct_message, "Hello, how are you?")
        create_message(followed_channel, "Hey @#{group.name}", Chat::GroupMention)
      end

      it "shows the group mention in the email subject" do
        chat_summary_with_subject(
          :chat_channel_and_dm,
          channel: followed_channel.name,
          name: direct_message.title(user),
        )
      end

      it "shows the group mention in the email body" do
        html = chat_summary_email.html_part.body.to_s

        expect(html).to include(direct_message.title(user))
        expect(html).to include(group.name)
      end

      describe "when the group is not mentionable" do
        before { group.update!(mentionable_level: Group::ALIAS_LEVELS[:nobody]) }

        it "does not show the group mention in the email subject" do
          chat_summary_with_subject(:chat_dm_1, name: direct_message.title(user), count: 1)
        end

        it "does not show the group mention in the email body" do
          html = chat_summary_email.html_part.body.to_s

          expect(html).to include(direct_message.title(user))
          expect(html).not_to include(group.name)
        end
      end

      describe "when user is removed from group" do
        before { group.remove(user) }

        it "does not show the group mention in the email subject" do
          chat_summary_with_subject(:chat_dm_1, name: direct_message.title(user), count: 1)
        end
      end
    end
  end

  describe "in a direct message channel with threads" do
    fab!(:message) do
      Fabricate(:chat_message, chat_channel: direct_message, user: other, created_at: 2.days.ago)
    end
    fab!(:thread) { Fabricate(:chat_thread, channel: direct_message, original_message: message) }
    fab!(:reply) { Fabricate(:chat_message, chat_channel: direct_message, thread:, user: other) }
    let(:watching) { Chat::NotificationLevels.all[:watching] }

    it "does not send a chat summary email for thread replies" do
      no_chat_summary_email
    end

    describe "when the user is watching the thread" do
      before do
        Fabricate(:user_chat_thread_membership, user: user, thread:, notification_level: watching)
      end

      it "sends a chat summary email" do
        chat_summary_email
      end
    end

    describe "when the user has 2 watched threads" do
      fab!(:message_2) do
        Fabricate(
          :chat_message,
          chat_channel: direct_message_2,
          user: another,
          created_at: 2.days.ago,
        )
      end
      fab!(:thread_2) do
        Fabricate(:chat_thread, channel: direct_message_2, original_message: message_2)
      end
      fab!(:thread_2_reply) do
        Fabricate(:chat_message, chat_channel: direct_message_2, thread: thread_2, user: another)
      end

      before do
        Fabricate(:user_chat_thread_membership, user: user, thread:, notification_level: watching)
        Fabricate(
          :user_chat_thread_membership,
          user: user,
          thread: thread_2,
          notification_level: watching,
        )
      end

      it "sends a chat summary email" do
        chat_summary_with_subject(:watched_threads, channel: direct_message.title(user), count: 1)
      end
    end

    describe "when another user is watching a thread" do
      before { thread.membership_for(other).update!(notification_level: watching) }

      it "does not send current user a chat summary email" do
        no_chat_summary_email
      end
    end
  end
end
