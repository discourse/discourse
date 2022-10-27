# frozen_string_literal: true

class ChangeChatChannelsTimestampColumnsToTimestampType < ActiveRecord::Migration[6.1]
  def change
    change_column_default :chat_channels, :created_at, nil
    change_column_default :chat_channels, :updated_at, nil

    # the earlier AddTimestampsToChatChannels migration has been modified,
    # originally it added the columns as :datetime types, now it has been
    # changed to use the correct :timestamp type, this exists check is here so
    # we only try and make this change on old tables created before
    if !column_exists?(:chat_channels, :created_at, :timestamp)
      change_column :chat_channels, :created_at, :timestamp
    end
    if !column_exists?(:chat_channels, :updated_at, :timestamp)
      change_column :chat_channels, :updated_at, :timestamp
    end
  end
end
