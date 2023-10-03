# frozen_string_literal: true

module Chat
  module BookmarkExtension
    extend ActiveSupport::Concern

    prepended { include TypeMappable }

    class_methods { def polymorphic_class_mapping = { "ChatMessage" => Chat::Message } }
  end
end
