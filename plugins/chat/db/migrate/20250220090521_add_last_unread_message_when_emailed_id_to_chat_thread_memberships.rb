# frozen_string_literal: true
class AddLastUnreadMessageWhenEmailedIdToChatThreadMemberships < ActiveRecord::Migration[7.2]
  def change
    add_column :user_chat_thread_memberships, :last_unread_message_when_emailed_id, :bigint
  end
end
