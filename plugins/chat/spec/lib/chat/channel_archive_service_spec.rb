# frozen_string_literal: true

describe Chat::ChannelArchiveService do
  class FakeArchiveError < StandardError
  end

  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:category)

  let(:topic_params) { { topic_title: "This will be a new topic", category_id: category.id } }

  before { SiteSetting.chat_enabled = true }

  describe "#create_archive_process" do
    before { 3.times { Fabricate(:chat_message, chat_channel: channel) } }

    it "marks the channel as read_only" do
      described_class.create_archive_process(
        chat_channel: channel,
        acting_user: user,
        topic_params: topic_params,
      )
      expect(channel.reload.status).to eq("read_only")
    end

    it "creates the chat channel archive record to save progress and topic params" do
      described_class.create_archive_process(
        chat_channel: channel,
        acting_user: user,
        topic_params: topic_params,
      )
      channel_archive = Chat::ChannelArchive.find_by(chat_channel: channel)
      expect(channel_archive.archived_by).to eq(user)
      expect(channel_archive.destination_topic_title).to eq("This will be a new topic")
      expect(channel_archive.destination_category_id).to eq(category.id)
      expect(channel_archive.total_messages).to eq(3)
      expect(channel_archive.archived_messages).to eq(0)
    end

    it "enqueues the archive job" do
      channel_archive =
        described_class.create_archive_process(
          chat_channel: channel,
          acting_user: user,
          topic_params: topic_params,
        )
      expect(
        job_enqueued?(
          job: Jobs::Chat::ChannelArchive,
          args: {
            chat_channel_archive_id: channel_archive.id,
          },
        ),
      ).to eq(true)
    end

    it "does nothing if there is already an archive record for the channel" do
      described_class.create_archive_process(
        chat_channel: channel,
        acting_user: user,
        topic_params: topic_params,
      )
      expect {
        described_class.create_archive_process(
          chat_channel: channel,
          acting_user: user,
          topic_params: topic_params,
        )
      }.not_to change { Chat::ChannelArchive.count }
    end

    it "does not count already deleted messages toward the archive total" do
      new_message = Fabricate(:chat_message, chat_channel: channel)
      new_message.trash!
      channel_archive =
        described_class.create_archive_process(
          chat_channel: channel,
          acting_user: user,
          topic_params: topic_params,
        )
      expect(channel_archive.total_messages).to eq(3)
    end
  end

  describe "#execute" do
    def create_messages(num)
      num.times { Fabricate(:chat_message, chat_channel: channel) }
    end

    def create_threaded_messages(num, title: nil)
      original_message = Fabricate(:chat_message, chat_channel: channel)
      thread =
        Fabricate(:chat_thread, channel: channel, title: title, original_message: original_message)
      (num - 1).times { Fabricate(:chat_message, chat_channel: channel, thread: thread) }
      thread.update!(replies_count: num - 1)
    end

    def start_archive
      @channel_archive =
        described_class.create_archive_process(
          chat_channel: channel,
          acting_user: user,
          topic_params: topic_params,
        )
    end

    context "when archiving to a new topic" do
      let(:topic_params) do
        { topic_title: "This will be a new topic", category_id: category.id, tags: %w[news gossip] }
      end

      it "makes a topic, deletes all the messages, creates posts for batches of messages, and changes the channel to archived" do
        create_messages(50) && start_archive
        reaction_message = Chat::Message.last
        Chat::MessageReaction.create!(
          chat_message: reaction_message,
          user: Fabricate(:user, refresh_auto_groups: true),
          emoji: "+1",
        )
        stub_const(Chat::ChannelArchiveService, "ARCHIVED_MESSAGES_PER_POST", 5) do
          described_class.new(@channel_archive).execute
        end

        @channel_archive.reload
        expect(@channel_archive.destination_topic.title).to eq("This will be a new topic")
        expect(@channel_archive.destination_topic.category).to eq(category)
        expect(@channel_archive.destination_topic.user).to eq(Discourse.system_user)
        expect(@channel_archive.destination_topic.tags.map(&:name)).to match_array(%w[news gossip])

        topic = @channel_archive.destination_topic
        expect(topic.posts.count).to eq(11)
        topic
          .posts
          .where.not(post_number: 1)
          .each do |post|
            expect(post.raw).to include("[chat")
            expect(post.raw).to include("noLink=\"true\"")
            expect(post.user).to eq(Discourse.system_user)

            if post.raw.include?(";#{reaction_message.id};")
              expect(post.raw).to include("reactions=")
            end
          end
        expect(topic.archived).to eq(true)

        expect(@channel_archive.archived_messages).to eq(50)
        expect(@channel_archive.chat_channel.status).to eq("archived")
        expect(@channel_archive.chat_channel.chat_messages.count).to eq(0)
      end

      xit "creates the correct posts for a channel with messages and threads" do
        channel.update!(threading_enabled: true)

        create_messages(2)
        create_threaded_messages(6, title: "a new thread")
        create_messages(7)
        create_threaded_messages(3)
        create_threaded_messages(27, title: "another long thread")
        create_messages(10)

        start_archive

        stub_const(Chat::ChannelArchiveService, "ARCHIVED_MESSAGES_PER_POST", 5) do
          described_class.new(@channel_archive).execute
        end

        @channel_archive.reload
        topic = @channel_archive.destination_topic
        expect(topic.posts.count).to eq(14)

        topic
          .posts
          .where.not(post_number: 1)
          .each do |post|
            case post.post_number
            when 2
              expect(post.raw).to include("a new thread")
              expect(post.raw).to include(
                I18n.t("chat.transcript.split_thread_range", start: 1, end: 2, total: 5),
              )
            when 3
              expect(post.raw).to include("a new thread")
              expect(post.raw).to include(
                I18n.t("chat.transcript.split_thread_range", start: 3, end: 5, total: 5),
              )
            when 5
              expect(post.raw).to include(
                "threadTitle=\"#{I18n.t("chat.transcript.default_thread_title")}\"",
              )
            when 10
              expect(post.raw).to include("another long thread")
              expect(post.raw).to include(
                I18n.t("chat.transcript.split_thread_range", start: 17, end: 20, total: 26),
              )
            end

            expect(post.raw).to include("[chat")
            expect(post.raw).to include("noLink=\"true\"")
            expect(post.user).to eq(Discourse.system_user)
          end
        expect(topic.archived).to eq(true)

        expect(@channel_archive.archived_messages).to eq(55)
        expect(@channel_archive.chat_channel.status).to eq("archived")
        expect(@channel_archive.chat_channel.chat_messages.count).to eq(0)
      end

      it "does not stop the process if the post length is too high (validations disabled)" do
        create_messages(50) && start_archive
        SiteSetting.max_post_length = 1
        described_class.new(@channel_archive).execute
        expect(@channel_archive.reload.complete?).to eq(true)
      end

      it "successfully links uploads from messages to the post" do
        create_messages(3) && start_archive
        UploadReference.create!(target: Chat::Message.last, upload: Fabricate(:upload))
        described_class.new(@channel_archive).execute
        expect(@channel_archive.reload.complete?).to eq(true)
        expect(@channel_archive.destination_topic.posts.last.upload_references.count).to eq(1)
      end

      it "successfully sends a private message to the archiving user" do
        create_messages(3) && start_archive
        described_class.new(@channel_archive).execute
        expect(@channel_archive.reload.complete?).to eq(true)
        pm_topic = Topic.private_messages.last
        expect(pm_topic.topic_allowed_users.first.user).to eq(@channel_archive.archived_by)
        expect(pm_topic.title).to eq(
          I18n.t("system_messages.chat_channel_archive_complete.subject_template"),
        )
      end

      it "does not continue archiving if the destination topic fails to be created" do
        SiteSetting.max_emojis_in_title = 1

        create_messages(3) && start_archive
        @channel_archive.update!(destination_topic_title: "Wow this is the new title :tada: :joy:")
        described_class.new(@channel_archive).execute
        expect(@channel_archive.reload.complete?).to eq(false)
        expect(@channel_archive.reload.failed?).to eq(true)
        expect(@channel_archive.archive_error).to eq("Title can't have more than 1 emoji")

        pm_topic = Topic.private_messages.last
        expect(pm_topic.title).to eq(
          I18n.t("system_messages.chat_channel_archive_failed.subject_template"),
        )
        expect(pm_topic.first_post.raw).to include("Title can't have more than 1 emoji")
      end

      it "uses the channel slug to autolink a hashtag for the channel in the PM" do
        create_messages(3) && start_archive
        described_class.new(@channel_archive).execute
        expect(@channel_archive.reload.complete?).to eq(true)
        pm_topic = Topic.private_messages.last
        expect(pm_topic.first_post.cooked).to have_tag(
          "a",
          with: {
            class: "hashtag-cooked",
            href: channel.relative_url,
            "data-type": "channel",
            "data-slug": channel.slug,
            "data-id": channel.id,
            "data-ref": "#{channel.slug}::channel",
          },
        ) do
          with_tag("span", with: { class: "hashtag-icon-placeholder" })
          with_tag("span", text: channel.title(user))
        end
      end

      describe "channel members" do
        before do
          create_messages(3)
          channel
            .chat_messages
            .map(&:user)
            .each do |user|
              Chat::UserChatChannelMembership.create!(
                chat_channel: channel,
                user: user,
                following: true,
              )
            end
        end

        it "unfollows (leaves) the channel for all users" do
          expect(
            Chat::UserChatChannelMembership.where(chat_channel: channel, following: true).count,
          ).to eq(3)
          start_archive
          described_class.new(@channel_archive).execute
          expect(@channel_archive.reload.complete?).to eq(true)
          expect(
            Chat::UserChatChannelMembership.where(chat_channel: channel, following: true).count,
          ).to eq(0)
        end

        it "resets unread state for all users" do
          Chat::UserChatChannelMembership.last.update!(
            last_read_message_id: channel.chat_messages.first.id,
          )
          start_archive
          described_class.new(@channel_archive).execute
          expect(@channel_archive.reload.complete?).to eq(true)
          expect(Chat::UserChatChannelMembership.last.last_read_message_id).to eq(
            channel.chat_messages.last.id,
          )
        end
      end

      describe "chat_archive_destination_topic_status setting" do
        context "when set to archived" do
          before { SiteSetting.chat_archive_destination_topic_status = "archived" }

          it "archives the topic" do
            create_messages(3) && start_archive
            described_class.new(@channel_archive).execute
            topic = @channel_archive.destination_topic
            topic.reload
            expect(topic.archived).to eq(true)
          end
        end

        context "when set to open" do
          before { SiteSetting.chat_archive_destination_topic_status = "open" }

          it "leaves the topic open" do
            create_messages(3) && start_archive
            described_class.new(@channel_archive).execute
            topic = @channel_archive.destination_topic
            topic.reload
            expect(topic.archived).to eq(false)
            expect(topic.open?).to eq(true)
          end
        end

        context "when set to closed" do
          before { SiteSetting.chat_archive_destination_topic_status = "closed" }

          it "closes the topic" do
            create_messages(3) && start_archive
            described_class.new(@channel_archive).execute
            topic = @channel_archive.destination_topic
            topic.reload
            expect(topic.archived).to eq(false)
            expect(topic.closed?).to eq(true)
          end
        end

        context "when archiving to an existing topic" do
          it "does not change the status of the topic" do
            create_messages(3) && start_archive
            @channel_archive.update(
              destination_topic_title: nil,
              destination_topic_id: Fabricate(:topic).id,
            )
            described_class.new(@channel_archive).execute
            topic = @channel_archive.destination_topic
            topic.reload
            expect(topic.archived).to eq(false)
            expect(topic.closed?).to eq(false)
          end
        end
      end
    end

    context "when archiving to an existing topic" do
      fab!(:topic)
      let(:topic_params) { { topic_id: topic.id } }

      before { 3.times { Fabricate(:post, topic: topic) } }

      it "deletes all the messages, creates posts for batches of messages, and changes the channel to archived" do
        create_messages(50) && start_archive
        reaction_message = Chat::Message.last
        Chat::MessageReaction.create!(
          chat_message: reaction_message,
          user: Fabricate(:user),
          emoji: "+1",
        )
        stub_const(Chat::ChannelArchiveService, "ARCHIVED_MESSAGES_PER_POST", 5) do
          described_class.new(@channel_archive).execute
        end

        @channel_archive.reload
        expect(@channel_archive.destination_topic.title).to eq(topic.title)
        expect(@channel_archive.destination_topic.category).to eq(topic.category)
        expect(@channel_archive.destination_topic.user).to eq(topic.user)

        topic = @channel_archive.destination_topic

        # existing posts + 10 archive posts
        expect(topic.posts.count).to eq(13)
        topic
          .posts
          .where.not(post_number: [1, 2, 3])
          .each do |post|
            expect(post.raw).to include("[chat")
            expect(post.raw).to include("noLink=\"true\"")
            expect(post.user).to eq(Discourse.system_user)

            if post.raw.include?(";#{reaction_message.id};")
              expect(post.raw).to include("reactions=")
            end
          end
        expect(topic.archived).to eq(false)

        expect(@channel_archive.archived_messages).to eq(50)
        expect(@channel_archive.chat_channel.status).to eq("archived")
        expect(@channel_archive.chat_channel.chat_messages.count).to eq(0)
      end

      it "handles errors gracefully, sends a private message to the archiving user, and is idempotent on retry" do
        create_messages(35) && start_archive

        Chat::ChannelArchiveService
          .any_instance
          .stubs(:create_post)
          .raises(FakeArchiveError.new("this is a test error"))

        stub_const(Chat::ChannelArchiveService, "ARCHIVED_MESSAGES_PER_POST", 5) do
          expect { described_class.new(@channel_archive).execute }.to raise_error(FakeArchiveError)
        end

        expect(@channel_archive.reload.archive_error).to eq("this is a test error")

        pm_topic = Topic.private_messages.last
        expect(pm_topic.topic_allowed_users.first.user).to eq(@channel_archive.archived_by)
        expect(pm_topic.title).to eq(
          I18n.t("system_messages.chat_channel_archive_failed.subject_template"),
        )

        Chat::ChannelArchiveService.any_instance.unstub(:create_post)
        stub_const(Chat::ChannelArchiveService, "ARCHIVED_MESSAGES_PER_POST", 5) do
          described_class.new(@channel_archive).execute
        end

        @channel_archive.reload
        expect(@channel_archive.archive_error).to eq(nil)
        expect(@channel_archive.archived_messages).to eq(35)
        expect(@channel_archive.complete?).to eq(true)
        # existing posts + 7 archive posts
        expect(topic.posts.count).to eq(10)
      end
    end
  end
end
