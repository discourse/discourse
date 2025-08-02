# frozen_string_literal: true

class AddActionCodeToTopicChatMessage < ActiveRecord::Migration[6.0]
  def change
    add_column :topic_chat_messages, :action_code, :string, null: true
  end
end
