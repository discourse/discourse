# frozen_string_literal: true
class AddChatFieldsToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_post_event_events, :chat_enabled, :boolean, default: false, null: false
    add_column :discourse_post_event_events, :chat_channel_id, :bigint
  end
end
