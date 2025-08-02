# frozen_string_literal: true

class AddJoinModeToChannelMemberships < ActiveRecord::Migration[7.0]
  def change
    add_column :user_chat_channel_memberships, :join_mode, :integer, null: false, default: 0
  end
end
