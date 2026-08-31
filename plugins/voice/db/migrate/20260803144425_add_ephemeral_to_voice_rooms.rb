# frozen_string_literal: true

class AddEphemeralToVoiceRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :voice_rooms, :ephemeral, :boolean, default: false, null: false
    add_column :voice_rooms, :last_occupied_at, :datetime

    # The cleanup job scans only ephemeral rooms; persistent rooms dominate
    # the table, so a partial index keeps that scan cheap.
    add_index :voice_rooms, :id, where: "ephemeral", name: "index_voice_rooms_on_ephemeral"
  end
end
