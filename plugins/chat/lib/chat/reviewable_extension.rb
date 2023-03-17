# frozen_string_literal: true

module Chat
  module ReviewableExtension
    extend ActiveSupport::Concern

    prepended do
      # the model used when loading type column
      def self.sti_class_for(name)
        return Chat::ReviewableMessage if name == "ReviewableChatMessage"
        super(name)
      end

      # the model used when loading target_type column
      def self.polymorphic_class_for(name)
        return Chat::Message if name == "ChatMessage"
        super(name)
      end

      # the type column value when saving a Chat::ReviewableMessage
      def self.sti_name
        return "ReviewableChatMessage" if self.to_s == "Chat::ReviewableMessage"
        super
      end
    end
  end
end
