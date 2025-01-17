# frozen_string_literal: true

class AddChatSendShortcutPreference < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :chat_send_shortcut, :integer, default: 0, null: false
  end
end
