# frozen_string_literal: true

require_dependency "reviewable_serializer"

module Chat
  class ReviewableChatMessageSerializer < ReviewableSerializer
    target_attributes :cooked
    payload_attributes :transcript_topic_id, :message_cooked
    attributes :target_id

    has_one :chat_channel, serializer: Chat::ChannelSerializer, root: false, embed: :objects

    def chat_channel
      object.chat_message.chat_channel
    end

    def target_id
      object.target&.id
    end
  end
end
