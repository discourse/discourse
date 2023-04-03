# frozen_string_literal: true

module Chat
  module Chatable
    extend ActiveSupport::Concern

    STI_CLASS_MAPPING = {
      "CategoryChannel" => Chat::CategoryChannel,
      "DirectMessageChannel" => Chat::DirectMessageChannel,
    }

    # the model used when loading type column
    def self.sti_class_for(name)
      STI_CLASS_MAPPING[name] if STI_CLASS_MAPPING.key?(name)
    end

    # the type column value
    def self.sti_name_for(klass)
      STI_CLASS_MAPPING.invert.fetch(klass)
    end

    POLYMORPHIC_CLASS_MAPPING = { "DirectMessage" => Chat::DirectMessage }

    # the model used when loading chatable_type column
    def self.polymorphic_class_for(name)
      POLYMORPHIC_CLASS_MAPPING[name] if POLYMORPHIC_CLASS_MAPPING.key?(name)
    end

    # the chatable_type column value
    def self.polymorphic_name_for(klass)
      POLYMORPHIC_CLASS_MAPPING.invert.fetch(klass)
    end

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
        raise("Unknown chatable #{self}")
      end
    end
  end
end
