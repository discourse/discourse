# frozen_string_literal: true

module Chat
  module GroupExtension
    extend ActiveSupport::Concern

    prepended do
      has_many :chat_mentions, class_name: "Chat::GroupMention", foreign_key: "target_id"
    end
  end
end
