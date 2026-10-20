# frozen_string_literal: true

# Sessions are analytics history: they must survive their room's deletion,
# which the FK made impossible (room destroy raised ForeignKeyViolation).
class RemoveVoiceSessionsRoomForeignKey < ActiveRecord::Migration[8.0]
  def up
    Migration::SafeMigrate.disable!

    remove_foreign_key :voice_sessions, column: :room_id, if_exists: true
  ensure
    Migration::SafeMigrate.enable!
  end

  def down
    # Re-adding would fail once rows reference deleted rooms.
    raise ActiveRecord::IrreversibleMigration
  end
end
