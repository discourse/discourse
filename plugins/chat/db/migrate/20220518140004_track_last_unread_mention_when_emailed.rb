# frozen_string_literal: true

class TrackLastUnreadMentionWhenEmailed < ActiveRecord::Migration[7.0]
  def change
    add_column :user_chat_channel_memberships, :last_unread_mention_when_emailed_id, :integer
  end
end
