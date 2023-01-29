# frozen_string_literal: true

class AddSlugUniqueIndexForChatChannels < ActiveRecord::Migration[7.0]
  def change
    remove_index :chat_channels, :slug
    add_index :chat_channels, :slug, unique: true
  end
end
