# frozen_string_literal: true

class SetLastViewedAtForUserChatChannelMemberships < ActiveRecord::Migration[7.0]
  def up
    DB.exec("UPDATE user_chat_channel_memberships SET last_viewed_at = NOW()")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
