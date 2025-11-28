# frozen_string_literal: true

class AddEmojiToChatChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_channels, :emoji, :string, null: true
  end
end
