# frozen_string_literal: true

module Chat
  module BookmarkExtension
    extend ActiveSupport::Concern

    prepended do
      def valid_bookmarkable_type
        return true if self.bookmarkable_type == "ChatMessage"
        super if defined?(super)
      end

      CLASS_MAPPING = { "ChatMessage" => Chat::Message }

      # the model used when loading chatable_type column
      def self.polymorphic_class_for(name)
        return CLASS_MAPPING[name] if CLASS_MAPPING.key?(name)
        super if defined?(super)
      end
    end
  end
end
