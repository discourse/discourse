# frozen_string_literal: true

module Chat
  class MessageReaction < ActiveRecord::Base
    self.table_name = "chat_message_reactions"

    belongs_to :chat_message, class_name: "Chat::Message"
    belongs_to :user
  end
end

# == Schema Information
#
# Table name: chat_message_reactions
#
#  id              :bigint           not null, primary key
#  chat_message_id :integer
#  user_id         :integer
#  emoji           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  chat_message_reactions_index  (chat_message_id,user_id,emoji) UNIQUE
#
