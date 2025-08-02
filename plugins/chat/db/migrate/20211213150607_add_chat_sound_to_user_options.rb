# frozen_string_literal: true
class AddChatSoundToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :chat_sound, :string, null: true
  end
end
