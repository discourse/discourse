# frozen_string_literal: true

module Chat
  # Toggles whether a thread reply is also shown in the channel stream.
  # Only channel-stream visibility and bookkeeping change; the thread is unaffected.
  class UpdateMessageBroadcast
    include Service::Base

    params do
      attribute :message_id, :integer
      attribute :channel_id, :integer
      attribute :broadcast, :boolean

      validates :message_id, presence: true
      validates :channel_id, presence: true
      validates :broadcast, inclusion: { in: [true, false] }
    end

    model :channel
    policy :channel_allows_message_creation, class_name: Chat::Channel::Policy::MessageCreation
    model :message
    policy :can_manage_broadcast
    policy :broadcastable_message

    transaction do
      step :apply_broadcast
      step :sync_channel_last_message
    end

    step :publish_broadcast_change

    private

    def fetch_channel(params:)
      Chat::Channel.find_by(id: params.channel_id)
    end

    def fetch_message(params:, channel:)
      Chat::Message
        .includes(thread: :channel, chat_channel: :chatable)
        .where(deleted_at: nil)
        .find_by(id: params.message_id, chat_channel_id: channel.id)
    end

    def can_manage_broadcast(guardian:, message:)
      guardian.can_broadcast_chat_message?(message)
    end

    def broadcastable_message(message:, channel:, params:)
      # Undo must work even after threading was turned off; only
      # enabling requires the channel to currently support threads.
      return message.broadcasted? if !params.broadcast
      channel.threading_enabled? && message.thread_reply?
    end

    def apply_broadcast(message:, params:)
      message.update!(broadcasted: params.broadcast)
    end

    def sync_channel_last_message(message:, params:, channel:)
      if params.broadcast
        channel.update!(last_message: message) if message.id > (channel.last_message_id || 0)
      elsif channel.last_message_id == message.id
        channel.update_last_message_id!
      end
    end

    # The thread copy is refreshed in place so its broadcast state updates live.
    def publish_broadcast_change(message:, params:, channel:)
      if params.broadcast
        Chat::Publisher.publish_to_channel!(
          channel,
          Chat::Publisher.serialize_message_with_type(message, :sent),
        )
        Chat::Publisher.publish_new_message_indicator(channel, message)
      else
        Chat::Publisher.publish_to_channel!(
          channel,
          Chat::Publisher.delete_payload(
            message,
            channel.latest_not_deleted_message_id(anchor_message_id: message.id),
          ).merge(broadcast_removed: true),
        )
      end

      Chat::Publisher.publish_to_targets!(
        [Chat::Publisher.thread_message_bus_channel(channel.id, message.thread_id)],
        channel,
        Chat::Publisher.serialize_message_with_type(message, :edit),
      )
    end
  end
end
