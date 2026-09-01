# frozen_string_literal: true
class AddMaxQualityProfileToVoiceRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :voice_rooms, :max_quality_profile, :integer
  end
end
