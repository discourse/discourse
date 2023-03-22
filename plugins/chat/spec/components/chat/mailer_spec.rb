# frozen_string_literal: true

require "rails_helper"

describe Chat::Mailer do
  fab!(:chatters_group) { Fabricate(:group) }
  fab!(:sender) { Fabricate(:user, group_ids: [chatters_group.id]) }
  fab!(:user_1) { Fabricate(:user, group_ids: [chatters_group.id], last_seen_at: 15.minutes.ago) }
  fab!(:chat_channel) { Fabricate(:category_channel) }
  fab!(:chat_message) { Fabricate(:chat_message, user: sender, chat_channel: chat_channel) }
  fab!(:user_1_chat_channel_membership) do
    Fabricate(
      :user_chat_channel_membership,
      user: user_1,
      chat_channel: chat_channel,
      last_read_message_id: nil,
    )
  end
  fab!(:private_chat_channel) do
    Group.refresh_automatic_groups!
    Chat::DirectMessageChannelCreator.create!(acting_user: sender, target_users: [sender, user_1])
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = chatters_group.id

    Fabricate(:user_chat_channel_membership, user: sender, chat_channel: chat_channel)
  end

  def assert_summary_skipped
    expect(
      job_enqueued?(job: :user_email, args: { type: "chat_summary", user_id: user_1.id }),
    ).to eq(false)
  end

  def assert_only_queued_once
    expect_job_enqueued(job: :user_email, args: { type: "chat_summary", user_id: user_1.id })
    expect(Jobs::UserEmail.jobs.size).to eq(1)
  end

  describe "for chat mentions" do
    fab!(:mention) { Fabricate(:chat_mention, user: user_1, chat_message: chat_message) }

    it "skips users without chat access" do
      chatters_group.remove(user_1)

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "skips users with summaries disabled" do
      user_1.user_option.update(chat_email_frequency: UserOption.chat_email_frequencies[:never])

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "skips a job if the user haven't read the channel since the last summary" do
      user_1_chat_channel_membership.update!(last_unread_mention_when_emailed_id: chat_message.id)

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "skips without chat enabled" do
      user_1.user_option.update(
        chat_enabled: false,
        chat_email_frequency: UserOption.chat_email_frequencies[:when_away],
      )

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "queues a job for users that was mentioned and never read the channel before" do
      described_class.send_unread_mentions_summary

      assert_only_queued_once
    end

    it "skips the job when the user was mentioned but already read the message" do
      user_1_chat_channel_membership.update!(last_read_message_id: chat_message.id)

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "skips the job when the user is not following a public channel anymore" do
      user_1_chat_channel_membership.update!(
        last_read_message_id: chat_message.id - 1,
        following: false,
      )

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "doesn’t skip the job when the user is not following a direct channel" do
      private_chat_channel
        .user_chat_channel_memberships
        .where(user_id: user_1.id)
        .update!(last_read_message_id: chat_message.id - 1, following: false)

      described_class.send_unread_mentions_summary

      assert_only_queued_once
    end

    it "skips users with unread messages from a different channel" do
      user_1_chat_channel_membership.update!(last_read_message_id: chat_message.id)
      second_channel = Fabricate(:category_channel)
      Fabricate(
        :user_chat_channel_membership,
        user: user_1,
        chat_channel: second_channel,
        last_read_message_id: chat_message.id - 1,
      )

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "only queues the job once for users who are member of multiple groups with chat access" do
      chatters_group_2 = Fabricate(:group, users: [user_1])
      SiteSetting.chat_allowed_groups = [chatters_group, chatters_group_2].map(&:id).join("|")

      described_class.send_unread_mentions_summary

      assert_only_queued_once
    end

    it "skips users when the mention was deleted" do
      chat_message.trash!

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "queues the job if the user has unread mentions and already read all the messages in the previous summary" do
      user_1_chat_channel_membership.update!(
        last_read_message_id: chat_message.id,
        last_unread_mention_when_emailed_id: chat_message.id,
      )
      unread_message = Fabricate(:chat_message, chat_channel: chat_channel, user: sender)
      Fabricate(:chat_mention, user: user_1, chat_message: unread_message)

      described_class.send_unread_mentions_summary

      expect_job_enqueued(job: :user_email, args: { type: "chat_summary", user_id: user_1.id })
      expect(Jobs::UserEmail.jobs.size).to eq(1)
    end

    it "skips users who were seen recently" do
      user_1.update!(last_seen_at: 2.minutes.ago)

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "doesn't mix mentions from other users" do
      mention.destroy!
      user_2 = Fabricate(:user, groups: [chatters_group], last_seen_at: 20.minutes.ago)
      Fabricate(
        :user_chat_channel_membership,
        user: user_2,
        chat_channel: chat_channel,
        last_read_message_id: nil,
      )
      new_message = Fabricate(:chat_message, chat_channel: chat_channel, user: sender)
      Fabricate(:chat_mention, user: user_2, chat_message: new_message)

      described_class.send_unread_mentions_summary

      expect(
        job_enqueued?(job: :user_email, args: { type: "chat_summary", user_id: user_1.id }),
      ).to eq(false)
      expect_job_enqueued(job: :user_email, args: { type: "chat_summary", user_id: user_2.id })
      expect(Jobs::UserEmail.jobs.size).to eq(1)
    end

    it "skips users when the message is older than 1 week" do
      chat_message.update!(created_at: 1.5.weeks.ago)

      described_class.send_unread_mentions_summary

      assert_summary_skipped
    end

    it "queues a job when the chat_allowed_groups is set to everyone" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]

      described_class.send_unread_mentions_summary

      assert_only_queued_once
    end

    describe "update the user membership after we send the email" do
      before { Jobs.run_immediately! }

      it "doesn't send the same summary the summary again if the user haven't read any channel messages since the last one" do
        user_1_chat_channel_membership.update!(last_read_message_id: chat_message.id - 1)
        described_class.send_unread_mentions_summary

        expect(user_1_chat_channel_membership.reload.last_unread_mention_when_emailed_id).to eq(
          chat_message.id,
        )

        another_channel_message = Fabricate(:chat_message, chat_channel: chat_channel, user: sender)
        Fabricate(:chat_mention, user: user_1, chat_message: another_channel_message)

        expect { described_class.send_unread_mentions_summary }.not_to change(
          Jobs::UserEmail.jobs,
          :size,
        )
      end

      it "only updates the last_message_read_when_emailed_id on the channel with unread mentions" do
        another_channel = Fabricate(:category_channel)
        another_channel_message =
          Fabricate(:chat_message, chat_channel: another_channel, user: sender)
        Fabricate(:chat_mention, user: user_1, chat_message: another_channel_message)
        another_channel_membership =
          Fabricate(
            :user_chat_channel_membership,
            user: user_1,
            chat_channel: another_channel,
            last_read_message_id: another_channel_message.id,
          )
        user_1_chat_channel_membership.update!(last_read_message_id: chat_message.id - 1)

        described_class.send_unread_mentions_summary

        expect(user_1_chat_channel_membership.reload.last_unread_mention_when_emailed_id).to eq(
          chat_message.id,
        )
        expect(another_channel_membership.reload.last_unread_mention_when_emailed_id).to be_nil
      end
    end
  end

  describe "for direct messages" do
    before { Fabricate(:chat_message, user: sender, chat_channel: private_chat_channel) }

    it "queue a job when the user has unread private mentions" do
      described_class.send_unread_mentions_summary

      assert_only_queued_once
    end

    it "only queues the job once when the user has mentions and private messages" do
      Fabricate(:chat_mention, user: user_1, chat_message: chat_message)

      described_class.send_unread_mentions_summary

      assert_only_queued_once
    end

    it "doesn't mix or update mentions from other users when joining tables" do
      user_2 = Fabricate(:user, groups: [chatters_group], last_seen_at: 20.minutes.ago)
      user_2_membership =
        Fabricate(
          :user_chat_channel_membership,
          user: user_2,
          chat_channel: chat_channel,
          last_read_message_id: chat_message.id,
        )
      Fabricate(:chat_mention, user: user_2, chat_message: chat_message)

      described_class.send_unread_mentions_summary

      assert_only_queued_once
      expect(user_2_membership.reload.last_unread_mention_when_emailed_id).to be_nil
    end
  end
end
