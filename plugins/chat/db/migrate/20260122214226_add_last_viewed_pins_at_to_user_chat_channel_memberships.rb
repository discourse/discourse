# frozen_string_literal: true

class AddLastViewedPinsAtToUserChatChannelMemberships < ActiveRecord::Migration[7.2]
  def change
    add_column :user_chat_channel_memberships, :last_viewed_pins_at, :datetime
  end
end
