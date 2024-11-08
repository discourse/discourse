# frozen_string_literal: true

class AlterChatIdsToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :chat_channel_archives, :chat_channel_id, :bigint
    change_column :chat_channels, :chatable_id, :bigint
    change_column :chat_drafts, :chat_channel_id, :bigint
    change_column :chat_mention_notifications, :chat_mention_id, :bigint
    change_column :chat_mention_notifications, :notification_id, :bigint
    change_column :chat_mentions, :chat_message_id, :bigint
    change_column :chat_message_reactions, :chat_message_id, :bigint
    change_column :chat_message_revisions, :chat_message_id, :bigint
    change_column :chat_messages, :chat_channel_id, :bigint
    change_column :chat_messages, :in_reply_to_id, :bigint
    change_column :chat_webhook_events, :chat_message_id, :bigint
    change_column :chat_webhook_events, :incoming_chat_webhook_id, :bigint
    change_column :direct_message_users, :direct_message_channel_id, :bigint
    change_column :incoming_chat_webhooks, :chat_channel_id, :bigint
    change_column :user_chat_channel_memberships, :chat_channel_id, :bigint
    change_column :user_chat_channel_memberships, :last_read_message_id, :bigint
    change_column :user_chat_channel_memberships, :last_unread_mention_when_emailed_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
