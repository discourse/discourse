# frozen_string_literal: true

class AutoJoinUsersToChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_channels, :auto_join_users, :boolean, null: false, default: false
  end
end
