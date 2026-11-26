# frozen_string_literal: true

class AddSpeakRequestsEnabledToLiveRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :live_rooms, :speak_requests_enabled, :boolean, default: true, null: false
  end
end
