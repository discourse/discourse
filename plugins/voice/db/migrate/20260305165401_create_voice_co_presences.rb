# frozen_string_literal: true

class CreateVoiceCoPresences < ActiveRecord::Migration[8.0]
  def change
    create_table :voice_co_presences do |t|
      t.integer :user_id_1, null: false
      t.integer :user_id_2, null: false
      t.date :date, null: false
      t.integer :total_seconds, null: false, default: 0
      t.integer :session_count, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :voice_co_presences, :users, column: :user_id_1
    add_foreign_key :voice_co_presences, :users, column: :user_id_2

    add_index :voice_co_presences,
              %i[user_id_1 user_id_2 date],
              unique: true,
              name: "idx_voice_co_presences_unique"
    add_index :voice_co_presences, %i[user_id_1 date]
    add_index :voice_co_presences, %i[user_id_2 date]

    reversible { |dir| dir.up { execute <<~SQL } }
          ALTER TABLE voice_co_presences
          ADD CONSTRAINT chk_voice_co_presences_user_order
          CHECK (user_id_1 < user_id_2)
        SQL
  end
end
