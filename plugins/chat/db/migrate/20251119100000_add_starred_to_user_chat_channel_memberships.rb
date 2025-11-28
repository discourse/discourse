# frozen_string_literal: true

class AddStarredToUserChatChannelMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :user_chat_channel_memberships, :starred, :boolean, default: false, null: false
    add_index :user_chat_channel_memberships, %i[user_id starred]
  end
end
