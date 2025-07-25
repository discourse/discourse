# frozen_string_literal: true

require_dependency "reviewable_serializer"

class ReviewableAiChatMessageSerializer < ReviewableSerializer
  payload_attributes :accuracies, :message_cooked
  target_attributes :cooked
  attributes :target_id

  has_one :chat_channel, serializer: AiChatChannelSerializer, root: false, embed: :objects

  def chat_channel
    object.chat_message&.chat_channel
  end

  def target_id
    object.target&.id
  end
end
