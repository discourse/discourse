# frozen_string_literal: true
class AddTimestampsToChatChannels < ActiveRecord::Migration[6.1]
  def change
    add_column :chat_channels, :created_at, :timestamp
    add_column :chat_channels, :updated_at, :timestamp

    DB.exec("UPDATE chat_channels SET created_at = NOW() WHERE created_at IS NULL")
    DB.exec("UPDATE chat_channels SET updated_at = NOW() WHERE updated_at IS NULL")

    change_column_null :chat_channels, :created_at, false
    change_column_null :chat_channels, :updated_at, false
  end
end
