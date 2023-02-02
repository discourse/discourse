# frozen_string_literal: true

require "rails_helper"

describe Chat::ChatChannelArchiveService do
  class FakeArchiveError < StandardError
  end

  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:user) { Fabricate(:user, admin: true) }
  fab!(:category) { Fabricate(:category) }
  let(:topic_params) { { topic_title: "This will be a new topic", category_id: category.id } }
  subject { Chat::ChatChannelArchiveService }

  before { SiteSetting.chat_enabled = true }

  describe "#create_archive_process" do
    before { 3.times { Fabricate(:chat_message, chat_channel: channel) } }

    it "marks the channel as read_only" do
      subject.create_archive_process(
        chat_channel: channel,
        acting_user: user,
        topic_params: topic_params,
      )
      expect(channel.reload.status).to eq("read_only")
    end

    it "creates the chat channel archive record to save progress and topic params" do
      subject.create_archive_process(
        chat_channel: channel,
        acting_user: user,
        topic_params: topic_params,
      )
      channel_archive = ChatChannelArchive.find_by(chat_channel: channel)
      expect(channel_archive.archived_by).to eq(user)
      expect(channel_archive.destination_topic_title).to eq("This will be a new topic")
      expect(channel_archive.destination_category_id).to eq(category.id)
      expect(channel_archive.total_messages).to eq(3)
      expect(channel_archive.archived_messages).to eq(0)
    end

    it "enqueues the archive job" do
      channel_archive =
        subject.create_archive_process(
          chat_channel: channel,
          acting_user: user,
          topic_params: topic_params,
        )
      expect(
        job_enqueued?(
          job: :chat_channel_archive,
          args: {
            chat_channel_archive_id: channel_archive.id,
          },
        ),
      ).to eq(true)
    end

    it "does nothing if there is already an archive record for the channel" do
      subject.create_archive_process(
        chat_channel: channel,
        acting_user: user,
        topic_params: topic_params,
      )
      expect {
        subject.create_archive_process(
          chat_channel: channel,
          acting_user: user,
          topic_params: topic_params,
        )
      }.not_to change { ChatChannelArchive.count }
    end

    it "does not count already deleted messages toward the archive total" do
      new_message = Fabricate(:chat_message, chat_channel: channel)
      new_message.trash!
      channel_archive =
        subject.create_archive_process(
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

    def start_archive
      @channel_archive =
        subject.create_archive_process(
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
        reaction_message = ChatMessage.last
        ChatMessageReaction.create!(
          chat_message: reaction_message,
          user: Fabricate(:user),
          emoji: "+1",
        )
        stub_const(Chat::ChatChannelArchiveService, "ARCHIVED_MESSAGES_PER_POST", 5) do
          subject.new(@channel_archive).execute
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

      it "does not stop the process if the post length is too high (validations disabled)" do
        create_messages(50) && start_archive
        SiteSetting.max_post_length = 1
        subject.new(@channel_archive).execute
        expect(@channel_archive.reload.complete?).to eq(true)
      end

      it "successfully links uploads from messages to the post" do
        create_messages(3) && start_archive
        UploadReference.create(target: ChatMessage.last, upload: Fabricate(:upload))
        subject.new(@channel_archive).execute
        expect(@channel_archive.reload.complete?).to eq(true)
        expect(@channel_archive.destination_topic.posts.last.upload_references.count).to eq(1)
      end

      it "successfully sends a private message to the archiving user" do
        create_messages(3) && start_archive
        subject.new(@channel_archive).execute
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
        subject.new(@channel_archive).execute
        expect(@channel_archive.reload.complete?).to eq(false)
        expect(@channel_archive.reload.failed?).to eq(true)
        expect(@channel_archive.archive_error).to eq("Title can't have more than 1 emoji")

        pm_topic = Topic.private_messages.last
        expect(pm_topic.title).to eq(
          I18n.t("system_messages.chat_channel_archive_failed.subject_template"),
        )
        expect(pm_topic.first_post.raw).to include("Title can't have more than 1 emoji")
      end

      context "when enable_experimental_hashtag_autocomplete" do
        before { SiteSetting.enable_experimental_hashtag_autocomplete = true }

        it "uses the channel slug to autolink a hashtag for the channel in the PM" do
          create_messages(3) && start_archive
          subject.new(@channel_archive).execute
          expect(@channel_archive.reload.complete?).to eq(true)
          pm_topic = Topic.private_messages.last
          expect(pm_topic.first_post.cooked).to include(
            "<a class=\"hashtag-cooked\" href=\"#{channel.relative_url}\" data-type=\"channel\" data-slug=\"#{channel.slug}\" data-ref=\"#{channel.slug}::channel\"><svg class=\"fa d-icon d-icon-comment svg-icon svg-node\"><use href=\"#comment\"></use></svg><span>#{channel.title(user)}</span></a>",
          )
        end
      end

      describe "channel members" do
        before do
          create_messages(3)
          channel
            .chat_messages
            .map(&:user)
            .each do |user|
              UserChatChannelMembership.create!(chat_channel: channel, user: user, following: true)
            end
        end

        it "unfollows (leaves) the channel for all users" do
          expect(
            UserChatChannelMembership.where(chat_channel: channel, following: true).count,
          ).to eq(3)
          start_archive
          subject.new(@channel_archive).execute
          expect(@channel_archive.reload.complete?).to eq(true)
          expect(
            UserChatChannelMembership.where(chat_channel: channel, following: true).count,
          ).to eq(0)
        end

        it "resets unread state for all users" do
          UserChatChannelMembership.last.update!(
            last_read_message_id: channel.chat_messages.first.id,
          )
          start_archive
          subject.new(@channel_archive).execute
          expect(@channel_archive.reload.complete?).to eq(true)
          expect(UserChatChannelMembership.last.last_read_message_id).to eq(
            channel.chat_messages.last.id,
          )
        end
      end

      describe "chat_archive_destination_topic_status setting" do
        context "when set to archived" do
          before { SiteSetting.chat_archive_destination_topic_status = "archived" }

          it "archives the topic" do
            create_messages(3) && start_archive
            subject.new(@channel_archive).execute
            topic = @channel_archive.destination_topic
            topic.reload
            expect(topic.archived).to eq(true)
          end
        end

        context "when set to open" do
          before { SiteSetting.chat_archive_destination_topic_status = "open" }

          it "leaves the topic open" do
            create_messages(3) && start_archive
            subject.new(@channel_archive).execute
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
            subject.new(@channel_archive).execute
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
            subject.new(@channel_archive).execute
            topic = @channel_archive.destination_topic
            topic.reload
            expect(topic.archived).to eq(false)
            expect(topic.closed?).to eq(false)
          end
        end
      end
    end

    context "when archiving to an existing topic" do
      fab!(:topic) { Fabricate(:topic) }
      let(:topic_params) { { topic_id: topic.id } }

      before { 3.times { Fabricate(:post, topic: topic) } }

      it "deletes all the messages, creates posts for batches of messages, and changes the channel to archived" do
        create_messages(50) && start_archive
        reaction_message = ChatMessage.last
        ChatMessageReaction.create!(
          chat_message: reaction_message,
          user: Fabricate(:user),
          emoji: "+1",
        )
        stub_const(Chat::ChatChannelArchiveService, "ARCHIVED_MESSAGES_PER_POST", 5) do
          subject.new(@channel_archive).execute
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
        Rails.logger = @fake_logger = FakeLogger.new
        create_messages(35) && start_archive

        Chat::ChatChannelArchiveService
          .any_instance
          .stubs(:create_post)
          .raises(FakeArchiveError.new("this is a test error"))

        stub_const(Chat::ChatChannelArchiveService, "ARCHIVED_MESSAGES_PER_POST", 5) do
          expect { subject.new(@channel_archive).execute }.to raise_error(FakeArchiveError)
        end

        expect(@channel_archive.reload.archive_error).to eq("this is a test error")

        pm_topic = Topic.private_messages.last
        expect(pm_topic.topic_allowed_users.first.user).to eq(@channel_archive.archived_by)
        expect(pm_topic.title).to eq(
          I18n.t("system_messages.chat_channel_archive_failed.subject_template"),
        )

        Chat::ChatChannelArchiveService.any_instance.unstub(:create_post)
        stub_const(Chat::ChatChannelArchiveService, "ARCHIVED_MESSAGES_PER_POST", 5) do
          subject.new(@channel_archive).execute
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
