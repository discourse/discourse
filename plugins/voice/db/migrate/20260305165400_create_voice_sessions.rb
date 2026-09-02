# frozen_string_literal: true

class CreateVoiceSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :voice_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :room, null: false, foreign_key: { to_table: :voice_rooms }
      t.datetime :joined_at, null: false
      t.datetime :left_at
      t.timestamps
    end

    add_index :voice_sessions, %i[user_id room_id joined_at]
    add_index :voice_sessions, %i[room_id joined_at]
    add_index :voice_sessions, %i[user_id joined_at]
    add_index :voice_sessions,
              :left_at,
              where: "left_at IS NULL",
              name: "idx_voice_sessions_orphaned"
  end
end
# rubocop:enable Discourse/NoAddReferenceOrAliasesActiveRecordMigration
