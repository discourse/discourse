# frozen_string_literal: true

# User deletion must not be blocked by voice rows; cleanup happens in the
# plugin's user_destroyed handler instead (rooms reassigned to the system
# user, memberships and co-presences removed, sessions kept as history).
class RemoveVoiceUserForeignKeys < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :voice_sessions, column: :user_id, if_exists: true
    remove_foreign_key :voice_room_memberships, column: :user_id, if_exists: true
    remove_foreign_key :voice_co_presences, column: :user_id_1, if_exists: true
    remove_foreign_key :voice_co_presences, column: :user_id_2, if_exists: true
    remove_foreign_key :voice_rooms, column: :creator_id, if_exists: true
  end

  def down
    # Re-adding would fail once rows reference deleted users.
    raise ActiveRecord::IrreversibleMigration
  end
end
