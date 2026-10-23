# frozen_string_literal: true

class AddCookedDescriptionToVoiceRooms < ActiveRecord::Migration[7.2]
  def change
    add_column :voice_rooms, :cooked_description, :text
  end
end
