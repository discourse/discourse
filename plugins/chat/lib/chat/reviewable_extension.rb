# frozen_string_literal: true

module Chat
  module ReviewableExtension
    extend ActiveSupport::Concern

    prepended { include TypeMappable }

    class_methods do
      def sti_class_mapping = { "ReviewableChatMessage" => Chat::ReviewableMessage }
      def polymorphic_class_mapping = { "ChatMessage" => Chat::Message }
    end
  end
end
