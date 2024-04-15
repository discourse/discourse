# frozen_string_literal: true

##
# From time to time, site admins may choose to sunset a chat channel and archive
# the messages within. It cannot be used for DM channels in its current iteration.
#
# To archive a channel, we mark it read_only first to prevent any further message
# additions or changes, and create a record to track whether the archive topic
# will be new or existing. When we archive the channel, messages are copied into
# posts in batches using the [chat] BBCode to quote the messages. The messages are
# deleted once the batch has its post made. The execute action of this class is
# idempotent, so if we fail halfway through the archive process it can be run again.
#
# Once all of the messages have been copied then we mark the channel as archived.
module Chat
  class ChannelArchiveService
    ARCHIVED_MESSAGES_PER_POST = 100

    class ArchiveValidationError < StandardError
      attr_reader :errors

      def initialize(errors: [])
        super
        @errors = errors
      end
    end

    def self.create_archive_process(chat_channel:, acting_user:, topic_params:)
      return if Chat::ChannelArchive.exists?(chat_channel: chat_channel)

      # Only need to validate topic params for a new topic, not an existing one.
      if topic_params[:topic_id].blank?
        valid, errors =
          Chat::ChannelArchiveService.validate_topic_params(Guardian.new(acting_user), topic_params)

        raise ArchiveValidationError.new(errors: errors) if !valid
      end

      Chat::ChannelArchive.transaction do
        chat_channel.read_only!(acting_user)

        archive =
          Chat::ChannelArchive.create!(
            chat_channel: chat_channel,
            archived_by: acting_user,
            total_messages: chat_channel.chat_messages.count,
            destination_topic_id: topic_params[:topic_id],
            destination_topic_title: topic_params[:topic_title],
            destination_category_id: topic_params[:category_id],
            destination_tags: topic_params[:tags],
          )
        Jobs.enqueue(Jobs::Chat::ChannelArchive, chat_channel_archive_id: archive.id)

        archive
      end
    end

    def self.retry_archive_process(chat_channel:)
      return if !chat_channel.chat_channel_archive&.failed?
      Jobs.enqueue(
        Jobs::Chat::ChannelArchive,
        chat_channel_archive_id: chat_channel.chat_channel_archive.id,
      )
      chat_channel.chat_channel_archive
    end

    def self.validate_topic_params(guardian, topic_params)
      topic_creator =
        TopicCreator.new(
          Discourse.system_user,
          guardian,
          {
            title: topic_params[:topic_title],
            category: topic_params[:category_id],
            tags: topic_params[:tags],
            import_mode: true,
          },
        )
      [topic_creator.valid?, topic_creator.errors.full_messages]
    end

    attr_reader :chat_channel_archive, :chat_channel, :chat_channel_title

    def initialize(chat_channel_archive)
      @chat_channel_archive = chat_channel_archive
      @chat_channel = chat_channel_archive.chat_channel
      @chat_channel_title = chat_channel.title(chat_channel_archive.archived_by)
      @archived_messages_ids = []
    end

    def execute
      chat_channel_archive.update(archive_error: nil)

      begin
        return if !ensure_destination_topic_exists!

        Rails.logger.info(
          "Creating posts from message batches for #{chat_channel_title} archive, #{chat_channel_archive.total_messages} messages to archive (#{chat_channel_archive.total_messages / ARCHIVED_MESSAGES_PER_POST} posts).",
        )

        # A batch should be idempotent, either the post is created and the
        # messages are deleted or we roll back the whole thing.
        #
        # At some point we may want to reconsider disabling post validations,
        # and add in things like dynamic resizing of the number of messages per
        # post based on post length, but that can be done later.
        #
        # Another future improvement is to send a MessageBus message for each
        # completed batch, so the UI can receive updates and show a progress
        # bar or something similar.

        buffer = []
        batch_thread_ranges = {}

        chat_channel
          .chat_messages
          .order("created_at ASC")
          .find_in_batches(batch_size: ARCHIVED_MESSAGES_PER_POST) do |message_batch|
            thread_ids = message_batch.map(&:thread_id).compact.uniq
            threads =
              chat_channel
                .chat_messages
                .where(
                  thread_id:
                    Chat::Message
                      .select(:thread_id)
                      .where(thread_id: thread_ids)
                      .group(:thread_id)
                      .having("count(*) > 1"),
                )
                .order("created_at ASC")
                .to_a

            full_batch = (buffer + message_batch + threads).uniq { |msg| msg.id }
            message_chunk = full_batch.group_by { |msg| msg.thread_id || msg.id }.values.flatten

            buffer.clear

            if message_chunk.size > ARCHIVED_MESSAGES_PER_POST
              post_last_message = message_chunk[ARCHIVED_MESSAGES_PER_POST - 1]

              thread = threads.select { |msg| msg.thread_id == post_last_message.thread_id }
              thread_om = thread.first

              if !thread_om.nil?
                thread_ranges =
                  calculate_thread_ranges(message_chunk, thread, thread_om, post_last_message)
              end
            end

            batch = []
            batch_thread_added = false

            message_chunk.each do |message|
              # When a thread spans across multiple posts and the first message is part of a thread in
              # a previous post, we need to duplicate the original message to give context to the user.

              if thread_om.present?
                if batch.empty? && message_chunk.size > ARCHIVED_MESSAGES_PER_POST &&
                     message&.thread_id == thread_om&.thread_id && message != thread_om
                  batch << thread_om

                  # We determine the correct range for the current part of the thread.
                  batch_thread_ranges[thread_om.id] = thread_ranges[message.thread_id].first
                  thread_ranges[message.thread_id].slice!(0)
                elsif thread_ranges.has_key?(message.thread_id) &&
                      thread_ranges[message.thread_id].present? && batch_thread_added == false
                  # We determine the correct range for the current part of the thread.
                  batch_thread_ranges[thread_om.id] = thread_ranges[message.thread_id].first
                  thread_ranges[message.thread_id].slice!(0)

                  batch_thread_added = true
                end
              end
              if message == thread_om && batch.size + 1 >= ARCHIVED_MESSAGES_PER_POST
                batch_size = batch.size + 1
              else
                batch << message
                batch_size = batch.size
              end

              if batch_size >= ARCHIVED_MESSAGES_PER_POST
                create_post_from_batch(batch, batch_thread_ranges)
                batch.clear
              end
            end

            buffer += batch
          end

        create_post_from_batch(buffer, batch_thread_ranges) unless buffer.empty?

        kick_all_users
        complete_archive
      rescue => err
        notify_archiver(:failed, error_message: err.message)
        raise err
      end
    end

    private

    # It's used to call the TranscriptService, which will
    # generate the markdown for a given set of messages.
    def create_post_from_batch(chat_messages, batch_thread_ranges)
      create_post(
        Chat::TranscriptService.new(
          chat_channel,
          chat_channel_archive.archived_by,
          messages_or_ids: chat_messages,
          thread_ranges: batch_thread_ranges,
          opts: {
            no_link: true,
            include_reactions: true,
          },
        ).generate_markdown,
      ) { delete_message_batch(chat_messages.map(&:id)) }
    end

    # Message batches can be greater than the maximum number of messages
    # per post if we also include threads. This is used to calculate all
    # the ranges when we split the threads that are included in the batch.
    def calculate_thread_ranges(message_chunk, thread, thread_om, post_last_message)
      ranges = {}
      thread_size = thread.size - 1
      last_thread_index = 0
      iterations = (message_chunk.size.to_f / (ARCHIVED_MESSAGES_PER_POST - 1)).ceil

      iterations.times do |index|
        if last_thread_index != thread_size
          if index == 0
            thread_index = thread.index(post_last_message)
          else
            next_post_last_message =
              message_chunk[(ARCHIVED_MESSAGES_PER_POST * (index + 1)) - index]
            if next_post_last_message&.thread_id == post_last_message&.thread_id
              thread_index = last_thread_index + ARCHIVED_MESSAGES_PER_POST - 1
            else
              thread_index = thread_size
            end
          end

          range =
            I18n.t(
              "chat.transcript.split_thread_range",
              start: last_thread_index + 1,
              end: thread_index,
              total: thread_size,
            )

          ranges[thread_om.thread_id] ||= []
          ranges[thread_om.thread_id] << range
          last_thread_index = thread_index
        end
      end

      ranges
    end

    def create_post(raw)
      pc = nil
      Post.transaction do
        pc =
          PostCreator.new(
            Discourse.system_user,
            raw: raw,
            # we must skip these because the posts are created in a big transaction,
            # we do them all at the end instead
            skip_jobs: true,
            # we do not want to be sending out notifications etc. from this
            # automatic background process
            import_mode: true,
            # don't want to be stopped by watched word or post length validations
            skip_validations: true,
            topic_id: chat_channel_archive.destination_topic_id,
          )

        pc.create

        # so we can also delete chat messages in the same transaction
        yield if block_given?
      end
      pc.enqueue_jobs
    end

    def ensure_destination_topic_exists!
      if !chat_channel_archive.destination_topic.present?
        Rails.logger.info("Creating topic for #{chat_channel_title} archive.")
        Topic.transaction do
          topic_creator =
            TopicCreator.new(
              Discourse.system_user,
              Guardian.new(chat_channel_archive.archived_by),
              {
                title: chat_channel_archive.destination_topic_title,
                category: chat_channel_archive.destination_category_id,
                tags: chat_channel_archive.destination_tags,
                import_mode: true,
              },
            )

          if topic_creator.valid?
            chat_channel_archive.update!(destination_topic: topic_creator.create)
          else
            Rails.logger.info("Destination topic for #{chat_channel_title} archive was not valid.")
            notify_archiver(
              :failed_no_topic,
              error_message: topic_creator.errors.full_messages.join("\n"),
            )
          end
        end

        if chat_channel_archive.destination_topic.present?
          Rails.logger.info("Creating first post for #{chat_channel_title} archive.")
          create_post(
            I18n.t(
              "chat.channel.archive.first_post_raw",
              channel_name: chat_channel_title,
              channel_url: chat_channel.url,
            ),
          )
        end
      else
        Rails.logger.info("Topic already exists for #{chat_channel_title} archive.")
      end

      if chat_channel_archive.destination_topic.present?
        update_destination_topic_status
        return true
      end

      false
    end

    def update_destination_topic_status
      # We only want to do this when the destination topic is new, not an
      # existing topic, because we don't want to update the status unexpectedly
      # on an existing topic
      if chat_channel_archive.new_topic?
        if SiteSetting.chat_archive_destination_topic_status == "archived"
          chat_channel_archive.destination_topic.update!(archived: true)
        elsif SiteSetting.chat_archive_destination_topic_status == "closed"
          chat_channel_archive.destination_topic.update!(closed: true)
        end
      end
    end

    def delete_message_batch(message_ids)
      Chat::Message.transaction do
        Chat::Message.where(id: message_ids).update_all(
          deleted_at: DateTime.now,
          deleted_by_id: chat_channel_archive.archived_by.id,
        )

        @archived_messages_ids = (@archived_messages_ids + message_ids).uniq
        chat_channel_archive.update!(archived_messages: @archived_messages_ids.length)
      end

      Rails.logger.info(
        "Archived #{chat_channel_archive.archived_messages} messages for #{chat_channel_title} archive.",
      )
    end

    def complete_archive
      Rails.logger.info("Creating posts completed for #{chat_channel_title} archive.")
      chat_channel.archived!(chat_channel_archive.archived_by)
      notify_archiver(:success)
    end

    def notify_archiver(result, error_message: nil)
      base_translation_params = {
        channel_hashtag_or_name: channel_hashtag_or_name,
        topic_title: chat_channel_archive.destination_topic&.title,
        topic_url: chat_channel_archive.destination_topic&.url,
        topic_validation_errors: result == :failed_no_topic ? error_message : nil,
      }

      if result == :failed || result == :failed_no_topic
        Discourse.warn_exception(
          error_message,
          message: "Error when archiving chat channel #{chat_channel_title}.",
          env: {
            chat_channel_id: chat_channel.id,
            chat_channel_name: chat_channel_title,
          },
        )
        error_translation_params =
          base_translation_params.merge(
            channel_url: chat_channel.url,
            messages_archived: chat_channel_archive.archived_messages,
          )
        chat_channel_archive.update(archive_error: error_message)
        message_translation_key =
          case result
          when :failed
            :chat_channel_archive_failed
          when :failed_no_topic
            :chat_channel_archive_failed_no_topic
          end
        SystemMessage.create_from_system_user(
          chat_channel_archive.archived_by,
          message_translation_key,
          error_translation_params,
        )
      else
        SystemMessage.create_from_system_user(
          chat_channel_archive.archived_by,
          :chat_channel_archive_complete,
          base_translation_params,
        )
      end

      Chat::Publisher.publish_archive_status(
        chat_channel,
        archive_status: result != :success ? :failed : :success,
        archived_messages: chat_channel_archive.archived_messages,
        archive_topic_id: chat_channel_archive.destination_topic_id,
        total_messages: chat_channel_archive.total_messages,
      )
    end

    def kick_all_users
      Chat::ChannelMembershipManager.new(chat_channel).unfollow_all_users
    end

    def channel_hashtag_or_name
      return "##{chat_channel.slug}::channel" if chat_channel.slug.present?
      chat_channel_title
    end
  end
end
