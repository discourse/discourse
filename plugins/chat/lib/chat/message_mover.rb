# frozen_string_literal: true

##
# Used to move chat messages from a chat channel to some other
# location.
#
# Channel -> Channel:
# -------------------
#
# Messages are sometimes misplaced and must be moved to another channel. For
# now we only support moving messages between public channels, handling the
# permissions and membership around moving things in and out of DMs is a little
# much for V1.
#
# The original messages will be deleted, and then similar to PostMover in core,
# all of the references associated to a chat message (e.g. reactions, bookmarks,
# notifications, revisions, mentions, uploads) will be updated to the new
# message IDs via a moved_chat_messages temporary table.
#
# Reply chains are a little complex. No reply chains are preserved when moving
# messages into a new channel. Remaining messages that referenced moved ones
# have their in_reply_to_id cleared so the data makes sense.
#
# The service supports moving threads. If any of the selected messages is the
# original message of a thread, the entire thread with all its replies will be
# moved to the destination channel. Moving individual messages out of a thread
# is still disabled.

module Chat
  class MessageMover
    class NoMessagesFound < StandardError
    end

    class InvalidChannel < StandardError
    end

    def initialize(acting_user:, source_channel:, message_ids:)
      @source_channel = source_channel
      @acting_user = acting_user
      @source_message_ids = message_ids
      @source_messages = find_messages(@source_message_ids, source_channel)
      @ordered_source_message_ids = @source_messages.map(&:id)
      @source_thread_ids = @source_messages.pluck(:thread_id).uniq.compact
    end

    def move_to_channel(destination_channel)
      if !@source_channel.public_channel? || !destination_channel.public_channel?
        raise InvalidChannel.new(I18n.t("chat.errors.message_move_invalid_channel"))
      end

      if @ordered_source_message_ids.empty?
        raise NoMessagesFound.new(I18n.t("chat.errors.message_move_no_messages_found"))
      end

      moved_messages = nil

      Chat::Message.transaction do
        create_temp_table_for_messages
        create_temp_table_for_threads
        moved_thread_ids = create_destination_threads_in_channel(destination_channel)
        moved_messages =
          find_messages(
            create_destination_messages_in_channel(destination_channel, moved_thread_ids),
            destination_channel,
          )
        bulk_insert_movement_metadata_for_messages
        update_message_references
        delete_source_messages
        update_reply_references
        update_tracking_state
        update_thread_references(moved_thread_ids)
        delete_source_threads
      end

      add_moved_placeholder(destination_channel, moved_messages.first)
      moved_messages
    end

    private

    def find_messages(message_ids, channel)
      Chat::Message
        .includes(thread: %i[original_message original_message_user])
        .where(chat_channel_id: channel.id)
        .where(
          "id IN (:message_ids) OR thread_id IN (SELECT thread_id FROM chat_messages WHERE id IN (:message_ids))",
          message_ids: message_ids,
        )
        .order("created_at ASC, id ASC")
    end

    def create_temp_table_for_messages
      DB.exec("DROP TABLE IF EXISTS moved_chat_messages") if Rails.env.test?

      DB.exec <<~SQL
      CREATE TEMPORARY TABLE moved_chat_messages (
        old_chat_message_id BIGINT,
        new_chat_message_id BIGINT
      ) ON COMMIT DROP;

      CREATE INDEX moved_chat_messages_old_chat_message_id ON moved_chat_messages(old_chat_message_id);
    SQL
    end

    def create_temp_table_for_threads
      DB.exec("DROP TABLE IF EXISTS moved_chat_threads") if Rails.env.test?

      DB.exec <<~SQL
      CREATE TEMPORARY TABLE moved_chat_threads (
        old_thread_id INTEGER,
        new_thread_id INTEGER
      ) ON COMMIT DROP;

      CREATE INDEX moved_chat_threads_old_thread_id ON moved_chat_threads(old_thread_id);
    SQL
    end

    def bulk_insert_movement_metadata_for_messages
      values_sql = @movement_metadata.map { |mm| "(#{mm[:old_id]}, #{mm[:new_id]})" }.join(",\n")
      DB.exec(
        "INSERT INTO moved_chat_messages(old_chat_message_id, new_chat_message_id) VALUES #{values_sql}",
      )
    end

    def create_destination_threads_in_channel(destination_channel)
      moved_thread_ids =
        @source_thread_ids.each_with_object({}) do |old_thread_id, hash|
          old_thread = Chat::Thread.find(old_thread_id)
          new_thread =
            Chat::Thread.create!(
              channel_id: destination_channel.id,
              original_message_user_id: old_thread.original_message_user_id,
              original_message_id: old_thread.original_message_id, # Placeholder, will be updated later
              replies_count: old_thread.replies_count,
              status: old_thread.status,
              title: old_thread.title,
            )
          hash[old_thread_id] = new_thread.id
        end

      moved_thread_ids
    end

    ##
    # We purposefully omit in_reply_to_id when creating the messages in the
    # new channel, because it could be pointing to a message that has not
    # been moved.
    def create_destination_messages_in_channel(destination_channel, moved_thread_ids)
      insert_messages = <<-SQL
        INSERT INTO chat_messages (
          chat_channel_id, user_id, last_editor_id, message, cooked, cooked_version, thread_id, created_at, updated_at
        )
        SELECT :destination_channel_id, user_id, last_editor_id, message, cooked, cooked_version, :new_thread_id, CLOCK_TIMESTAMP(), CLOCK_TIMESTAMP()
        FROM chat_messages
        WHERE id = :source_message_id
        RETURNING id
      SQL

      moved_message_ids =
        @source_messages.map do |source_message|
          new_thread_id = moved_thread_ids[source_message.thread_id]

          new_message_id =
            DB.query_single(
              insert_messages,
              {
                destination_channel_id: destination_channel.id,
                new_thread_id: new_thread_id,
                source_message_id: source_message.id,
              },
            ).first

          new_message_id
        end
      @movement_metadata =
        moved_message_ids.map.with_index do |chat_message_id, idx|
          { old_id: @ordered_source_message_ids[idx], new_id: chat_message_id }
        end
      moved_message_ids
    end

    def update_message_references
      DB.exec(<<~SQL)
      UPDATE chat_message_reactions cmr
      SET chat_message_id = mm.new_chat_message_id
      FROM moved_chat_messages mm
      WHERE cmr.chat_message_id = mm.old_chat_message_id
    SQL

      DB.exec(<<~SQL, target_type: Chat::Message.polymorphic_name)
      UPDATE upload_references uref
      SET target_id = mm.new_chat_message_id
      FROM moved_chat_messages mm
      WHERE uref.target_id = mm.old_chat_message_id AND uref.target_type = :target_type
    SQL

      DB.exec(<<~SQL)
      UPDATE chat_mentions cment
      SET chat_message_id = mm.new_chat_message_id
      FROM moved_chat_messages mm
      WHERE cment.chat_message_id = mm.old_chat_message_id
    SQL

      DB.exec(<<~SQL)
      UPDATE chat_message_revisions crev
      SET chat_message_id = mm.new_chat_message_id
      FROM moved_chat_messages mm
      WHERE crev.chat_message_id = mm.old_chat_message_id
    SQL

      DB.exec(<<~SQL)
      UPDATE chat_webhook_events cweb
      SET chat_message_id = mm.new_chat_message_id
      FROM moved_chat_messages mm
      WHERE cweb.chat_message_id = mm.old_chat_message_id
    SQL
    end

    def delete_source_messages
      # We do this so @source_messages is not nulled out, which is the
      # case when using update_all here.
      DB.exec(
        <<~SQL,
      UPDATE chat_messages
      SET deleted_at = NOW(), deleted_by_id = :deleted_by_id
      WHERE id IN (:source_message_ids)
      OR thread_id IN (:source_thread_ids)
    SQL
        source_message_ids: @source_message_ids,
        deleted_by_id: @acting_user.id,
        source_thread_ids: @source_thread_ids,
      )
      Chat::Publisher.publish_bulk_delete!(@source_channel, @source_message_ids)
    end

    def add_moved_placeholder(destination_channel, first_moved_message)
      @source_channel.add(Discourse.system_user)
      Chat::CreateMessage.call(
        guardian: Discourse.system_user.guardian,
        params: {
          chat_channel_id: @source_channel.id,
          message:
            I18n.t(
              "chat.channel.messages_moved",
              count: @source_message_ids.length,
              acting_username: @acting_user.username,
              channel_name: destination_channel.title(@acting_user),
              first_moved_message_url: first_moved_message.url,
            ),
        },
      )
    end

    def update_reply_references
      DB.exec(<<~SQL, deleted_reply_to_ids: @source_message_ids)
      UPDATE chat_messages
      SET in_reply_to_id = NULL
      WHERE in_reply_to_id IN (:deleted_reply_to_ids)
    SQL
    end

    def update_thread_references(moved_thread_ids)
      Chat::Thread.transaction do
        moved_thread_ids.each do |old_thread_id, new_thread_id|
          thread = Chat::Thread.find(new_thread_id)

          new_original_message_id, new_last_message_id =
            DB.query_single(<<-SQL, new_thread_id: new_thread_id)
          SELECT MIN(id), MAX(id)
          FROM chat_messages
          WHERE thread_id = :new_thread_id
        SQL

          thread.update!(
            original_message_id: new_original_message_id,
            last_message_id: new_last_message_id,
          )

          thread.set_replies_count_cache(thread.replies_count)
        end
      end
    end

    def delete_source_threads
      @source_thread_ids.each do |thread_id|
        thread = Chat::Thread.find_by(id: thread_id)
        thread.destroy if thread.present?
      end
    end

    def update_tracking_state
      ::Chat::Action::ResetUserLastReadChannelMessage.call(@source_message_ids, @source_channel.id)
    end
  end
end
