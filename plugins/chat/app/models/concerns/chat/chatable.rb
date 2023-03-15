# frozen_string_literal: true

module Chat
  module Chatable
    extend ActiveSupport::Concern

    def chat_channel
      channel_class.new(chatable: self)
    end

    def create_chat_channel!(**args)
      channel_class.create!(args.merge(chatable: self))
    end

    private

    def channel_class
      case self
      when Chat::DirectMessage
        Chat::DirectMessageChannel
      when Category
        Chat::CategoryChannel
      else
        "Chat::#{self.class}Channel".safe_constantize || raise("Unknown chatable #{self}")
      end
    end
  end
end
