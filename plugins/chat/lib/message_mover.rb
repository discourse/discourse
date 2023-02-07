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
# Threads are even more complex. No threads are preserved when moving messages
# into a new channel, they end up as just a flat series of messages that are
# not in a chain. If the original message of a thread and N other messages
# in that thread, then any messages left behind just get placed into a new
# thread. Message moving will be disabled in the thread UI while
# enable_experimental_chat_threaded_discussions is present, its too complicated
# to have end users reason about for now, and we may want a standalone
# "Move Thread" UI later on.
class Chat::MessageMover
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
  end

  def move_to_channel(destination_channel)
    if !@source_channel.public_channel? || !destination_channel.public_channel?
      raise InvalidChannel.new(I18n.t("chat.errors.message_move_invalid_channel"))
    end

    if @ordered_source_message_ids.empty?
      raise NoMessagesFound.new(I18n.t("chat.errors.message_move_no_messages_found"))
    end

    moved_messages = nil

    ChatMessage.transaction do
      create_temp_table
      moved_messages =
        find_messages(
          create_destination_messages_in_channel(destination_channel),
          destination_channel,
        )
      bulk_insert_movement_metadata
      update_references
      delete_source_messages
      update_reply_references
      update_thread_references
    end

    add_moved_placeholder(destination_channel, moved_messages.first)
    moved_messages
  end

  private

  def find_messages(message_ids, channel)
    ChatMessage
      .includes(thread: %i[original_message original_message_user])
      .where(id: message_ids, chat_channel_id: channel.id)
      .order("created_at ASC, id ASC")
  end

  def create_temp_table
    DB.exec("DROP TABLE IF EXISTS moved_chat_messages") if Rails.env.test?

    DB.exec <<~SQL
      CREATE TEMPORARY TABLE moved_chat_messages (
        old_chat_message_id INTEGER,
        new_chat_message_id INTEGER
      ) ON COMMIT DROP;

      CREATE INDEX moved_chat_messages_old_chat_message_id ON moved_chat_messages(old_chat_message_id);
    SQL
  end

  def bulk_insert_movement_metadata
    values_sql = @movement_metadata.map { |mm| "(#{mm[:old_id]}, #{mm[:new_id]})" }.join(",\n")
    DB.exec(
      "INSERT INTO moved_chat_messages(old_chat_message_id, new_chat_message_id) VALUES #{values_sql}",
    )
  end

  ##
  # We purposefully omit in_reply_to_id when creating the messages in the
  # new channel, because it could be pointing to a message that has not
  # been moved.
  def create_destination_messages_in_channel(destination_channel)
    query_args = {
      message_ids: @ordered_source_message_ids,
      destination_channel_id: destination_channel.id,
    }
    moved_message_ids = DB.query_single(<<~SQL, query_args)
      INSERT INTO chat_messages(
        chat_channel_id, user_id, last_editor_id, message, cooked, cooked_version, created_at, updated_at
      )
      SELECT :destination_channel_id,
             user_id,
             last_editor_id,
             message,
             cooked,
             cooked_version,
             CLOCK_TIMESTAMP(),
             CLOCK_TIMESTAMP()
      FROM chat_messages
      WHERE id IN (:message_ids)
      RETURNING id
    SQL

    @movement_metadata =
      moved_message_ids.map.with_index do |chat_message_id, idx|
        { old_id: @ordered_source_message_ids[idx], new_id: chat_message_id }
      end
    moved_message_ids
  end

  def update_references
    DB.exec(<<~SQL)
      UPDATE chat_message_reactions cmr
      SET chat_message_id = mm.new_chat_message_id
      FROM moved_chat_messages mm
      WHERE cmr.chat_message_id = mm.old_chat_message_id
    SQL

    DB.exec(<<~SQL)
      UPDATE upload_references uref
      SET target_id = mm.new_chat_message_id
      FROM moved_chat_messages mm
      WHERE uref.target_id = mm.old_chat_message_id AND uref.target_type = 'ChatMessage'
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
    DB.exec(<<~SQL, source_message_ids: @source_message_ids, deleted_by_id: @acting_user.id)
      UPDATE chat_messages
      SET deleted_at = NOW(), deleted_by_id = :deleted_by_id
      WHERE id IN (:source_message_ids)
    SQL
    ChatPublisher.publish_bulk_delete!(@source_channel, @source_message_ids)
  end

  def add_moved_placeholder(destination_channel, first_moved_message)
    Chat::ChatMessageCreator.create(
      chat_channel: @source_channel,
      user: Discourse.system_user,
      content:
        I18n.t(
          "chat.channel.messages_moved",
          count: @source_message_ids.length,
          acting_username: @acting_user.username,
          channel_name: destination_channel.title(@acting_user),
          first_moved_message_url: first_moved_message.url,
        ),
    )
  end

  def update_reply_references
    DB.exec(<<~SQL, deleted_reply_to_ids: @source_message_ids)
      UPDATE chat_messages
      SET in_reply_to_id = NULL
      WHERE in_reply_to_id IN (:deleted_reply_to_ids)
    SQL
  end

  def update_thread_references
    threads_to_update = []
    @source_messages
      .select { |message| message.thread_id.present? }
      .each do |message_with_thread|
        # If one of the messages we are moving is the original message in a thread,
        # then all the remaining messages for that thread must be moved to a new one,
        # otherwise they will be pointing to a thread in a different channel.
        if message_with_thread.thread.original_message_id == message_with_thread.id
          threads_to_update << message_with_thread.thread
        end
      end

    threads_to_update.each do |thread|
      # NOTE: We may want to do something with the old empty thread at some
      # point, maybe close or delete it. For now just leave it dangling.
      next if thread.chat_messages.empty?

      original_message = thread.chat_messages.first
      new_thread =
        ChatThread.create(
          original_message: original_message,
          original_message_user: original_message.user,
          channel: @source_channel,
        )
      thread.chat_messages.update_all(thread_id: new_thread.id)
    end
  end
end
