# frozen_string_literal: true

class AddPinnedToUserChatChannelMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :user_chat_channel_memberships, :pinned, :boolean, default: false, null: false
    add_index :user_chat_channel_memberships, %i[user_id pinned]
  end
end
