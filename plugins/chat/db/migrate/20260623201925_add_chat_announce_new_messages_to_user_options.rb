# frozen_string_literal: true
class AddChatAnnounceNewMessagesToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :chat_announce_new_messages, :boolean, default: true, null: false
  end
end
