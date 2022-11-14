# frozen_string_literal: true
class AddDescriptionToChatChannels < ActiveRecord::Migration[6.1]
  def change
    add_column :chat_channels, :description, :text, null: true
  end
end
