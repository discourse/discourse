# frozen_string_literal: true

module Chat
  class ViewSerializer < ApplicationSerializer
    attributes :meta, :chat_messages, :threads, :tracking, :unread_thread_overview, :channel

    def threads
      return [] if !object.threads

      object.threads.map do |thread|
        Chat::ThreadSerializer.new(
          thread,
          scope: scope,
          membership: object.thread_memberships.find { |m| m.thread_id == thread.id },
          participants: object.thread_participants[thread.id],
          include_preview: true,
          root: nil,
        )
      end
    end

    def tracking
      object.tracking || {}
    end

    def unread_thread_overview
      object.unread_thread_overview || {}
    end

    def include_threads?
      include_thread_data?
    end

    def include_unread_thread_overview?
      include_thread_data?
    end

    def include_thread_data?
      channel.threading_enabled && SiteSetting.enable_experimental_chat_threaded_discussions
    end

    def channel
      object.chat_channel
    end

    def chat_messages
      ActiveModel::ArraySerializer.new(
        object.chat_messages,
        each_serializer: Chat::MessageSerializer,
        reviewable_ids: object.reviewable_ids,
        user_flag_statuses: object.user_flag_statuses,
        chat_channel: object.chat_channel,
        scope: scope,
      )
    end

    def meta
      meta_hash = {
        channel_id: object.chat_channel.id,
        can_flag: scope.can_flag_in_chat_channel?(object.chat_channel),
        channel_status: object.chat_channel.status,
        user_silenced: !scope.can_create_chat_message?,
        can_moderate: scope.can_moderate_chat?(object.chat_channel.chatable),
        can_delete_self: scope.can_delete_own_chats?(object.chat_channel.chatable),
        can_delete_others: scope.can_delete_other_chats?(object.chat_channel.chatable),
        channel_message_bus_last_id:
          MessageBus.last_id(Chat::Publisher.root_message_bus_channel(object.chat_channel.id)),
      }
      meta_hash[
        :can_load_more_past
      ] = object.can_load_more_past unless object.can_load_more_past.nil?
      meta_hash[
        :can_load_more_future
      ] = object.can_load_more_future unless object.can_load_more_future.nil?
      meta_hash
    end
  end
end
