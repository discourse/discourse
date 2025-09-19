# frozen_string_literal: true

module Chat
  class MessageSearchData < ActiveRecord::Base
    self.table_name = "chat_message_search_data"
    self.primary_key = :chat_message_id
    belongs_to :chat_message
    validates_presence_of :search_data
  end
end

# == Schema Information
#
# Table name: chat_message_search_data
#
#  locale          :text
#  raw_data        :text
#  search_data     :tsvector
#  version         :integer          default(0)
#  chat_message_id :bigint           not null, primary key
#
# Indexes
#
#  idx_search_chat_message  (search_data) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (chat_message_id => chat_messages.id) ON DELETE => cascade
#
