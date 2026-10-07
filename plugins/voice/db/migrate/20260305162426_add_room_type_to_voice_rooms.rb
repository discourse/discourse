# frozen_string_literal: true

class AddRoomTypeToVoiceRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :voice_rooms, :room_type, :integer, default: 0, null: false
  end
end
