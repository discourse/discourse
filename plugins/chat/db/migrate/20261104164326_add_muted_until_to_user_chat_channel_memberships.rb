# frozen_string_literal: true
class AddMutedUntilToUserChatChannelMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :user_chat_channel_memberships, :muted_until, :datetime
  end
end
