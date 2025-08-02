# frozen_string_literal: true

class AddLastViewedAtToUserChatChannelMemberships < ActiveRecord::Migration[7.0]
  def change
    add_column :user_chat_channel_memberships,
               :last_viewed_at,
               :datetime,
               null: false,
               default: -> { "CURRENT_TIMESTAMP" }
  end
end
