# frozen_string_literal: true
#
class AddStatusToChatChannel < ActiveRecord::Migration[6.1]
  def change
    add_column :chat_channels, :status, :integer, default: 0, null: false
    add_index :chat_channels, :status
  end
end
