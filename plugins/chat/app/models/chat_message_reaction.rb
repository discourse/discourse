# frozen_string_literal: true

class ChatMessageReaction < ActiveRecord::Base
  belongs_to :chat_message
  belongs_to :user
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
