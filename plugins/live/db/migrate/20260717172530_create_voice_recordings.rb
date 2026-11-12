# frozen_string_literal: true

class CreateVoiceRecordings < ActiveRecord::Migration[8.0]
  def change
    create_table :voice_recordings do |t|
      t.bigint :room_id, null: false
      t.bigint :started_by_id, null: false
      t.string :egress_id, null: false
      t.integer :status, null: false, default: 0
      t.string :filepath, null: false
      t.string :filename
      t.string :location
      t.bigint :duration_ms
      t.bigint :size_bytes
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.timestamps
    end

    add_index :voice_recordings, :egress_id, unique: true
    add_index :voice_recordings, %i[room_id started_at]
  end
end
