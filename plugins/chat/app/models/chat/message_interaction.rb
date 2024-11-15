# frozen_string_literal: true

module Chat
  class MessageInteraction < ActiveRecord::Base
    self.table_name = "chat_message_interactions"

    belongs_to :user
    belongs_to :message, class_name: "Chat::Message", foreign_key: "chat_message_id"
  end
end
