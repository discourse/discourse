# frozen_string_literal: true

class CreateGamificationScoreEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :gamification_score_events do |t|
      t.integer :user_id, null: false
      t.date :date, null: false
      t.integer :points, null: false
      t.text :description, null: true

      t.timestamps
    end

    add_index :gamification_score_events, %i[user_id date], unique: false
    add_index :gamification_score_events, %i[date], unique: false
  end
end
