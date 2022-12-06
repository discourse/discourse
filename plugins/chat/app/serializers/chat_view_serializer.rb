# frozen_string_literal: true

class ChatViewSerializer < ApplicationSerializer
  attributes :meta, :chat_messages

  def chat_messages
    ActiveModel::ArraySerializer.new(
      object.chat_messages,
      each_serializer: ChatMessageSerializer,
      reviewable_ids: object.reviewable_ids,
      user_flag_statuses: object.user_flag_statuses,
      chat_channel: object.chat_channel,
      scope: scope,
    )
  end

  def meta
    meta_hash = {
      can_flag: scope.can_flag_in_chat_channel?(object.chat_channel),
      channel_status: object.chat_channel.status,
      user_silenced: !scope.can_create_chat_message?,
      can_moderate: scope.can_moderate_chat?(object.chat_channel.chatable),
      can_delete_self: scope.can_delete_own_chats?(object.chat_channel.chatable),
      can_delete_others: scope.can_delete_other_chats?(object.chat_channel.chatable),
      channel_message_bus_last_id: MessageBus.last_id("/chat/#{object.chat_channel.id}"),
    }
    meta_hash[:can_load_more_past] = object.can_load_more_past unless object.can_load_more_past.nil?
    meta_hash[
      :can_load_more_future
    ] = object.can_load_more_future unless object.can_load_more_future.nil?
    meta_hash
  end
end
