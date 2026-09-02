# frozen_string_literal: true
class AddVideoEnabledToVoiceRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :voice_rooms, :video_enabled, :boolean, null: false, default: true
  end
end
