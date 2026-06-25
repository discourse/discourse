# frozen_string_literal: true
class AddChatNewMessageSoundToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :chat_new_message_sound, :boolean, default: false, null: false
  end
end
