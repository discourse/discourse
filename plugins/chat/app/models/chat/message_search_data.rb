# frozen_string_literal: true

module Chat
  class MessageSearchData < ActiveRecord::Base
    self.table_name = "chat_message_search_data"
    self.primary_key = :chat_message_id
    belongs_to :chat_message
    validates_presence_of :search_data
  end
end
