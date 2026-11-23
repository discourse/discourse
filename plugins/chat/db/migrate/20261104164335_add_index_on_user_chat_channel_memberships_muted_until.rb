# frozen_string_literal: true
class AddIndexOnUserChatChannelMembershipsMutedUntil < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :user_chat_channel_memberships,
                 :muted_until,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :user_chat_channel_memberships,
              :muted_until,
              algorithm: :concurrently,
              where: "muted_until IS NOT NULL"
  end
end
