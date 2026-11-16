# frozen_string_literal: true
class AddLivekitEnabledToVoiceRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :voice_rooms, :livekit_enabled, :boolean, null: false, default: false
  end
end
