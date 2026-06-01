# frozen_string_literal: true
class AddAiConversationsSendOnEnterToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :ai_conversations_send_on_enter, :boolean, default: true, null: false
  end
end
