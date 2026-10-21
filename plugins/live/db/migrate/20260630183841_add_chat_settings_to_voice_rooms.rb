# frozen_string_literal: true
class AddChatSettingsToVoiceRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :voice_rooms, :chat_channel_id, :bigint
    add_column :voice_rooms, :chat_idle_minutes, :integer, default: 15, null: false
    add_column :voice_rooms, :chat_thread_title_template, :string
    add_index :voice_rooms, :chat_channel_id
  end
end
