# frozen_string_literal: true

class AddStageSessionSpeakersAndRequestToggle < ActiveRecord::Migration[8.0]
  def change
    # A speaker approved from the request queue only holds the role until the
    # room empties. `fallback_role` is what the row reverts to (NULL: the row
    # did not exist before the grant, so it is deleted).
    add_column :live_room_memberships, :session_only, :boolean, null: false, default: false
    add_column :live_room_memberships, :fallback_role, :integer

    add_column :live_rooms, :speak_requests_enabled, :boolean, null: false, default: true
  end
end
