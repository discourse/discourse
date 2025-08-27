# frozen_string_literal: true

class ChatMessageCustomPrompt < ActiveRecord::Base
  # belongs_to chat message but going to avoid the cross dependency for now
end

# == Schema Information
#
# Table name: chat_message_custom_prompts
#
#  id            :bigint           not null, primary key
#  message_id    :bigint           not null
#  custom_prompt :json             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_chat_message_custom_prompts_on_message_id  (message_id) UNIQUE
#
