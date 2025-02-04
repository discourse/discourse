# frozen_string_literal: true

module Chat
  class MessageInteraction < ActiveRecord::Base
    self.table_name = "chat_message_interactions"

    belongs_to :user
    belongs_to :message, class_name: "Chat::Message", foreign_key: "chat_message_id"
  end
end

# == Schema Information
#
# Table name: chat_message_interactions
#
#  id              :bigint           not null, primary key
#  user_id         :bigint           not null
#  chat_message_id :bigint           not null
#  action          :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_chat_message_interactions_on_chat_message_id  (chat_message_id)
#  index_chat_message_interactions_on_user_id          (user_id)
#
