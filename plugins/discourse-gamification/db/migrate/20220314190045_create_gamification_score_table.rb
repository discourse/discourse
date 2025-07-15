# frozen_string_literal: true
class CreateGamificationScoreTable < ActiveRecord::Migration[6.1]
  def change
    create_table :gamification_scores do |t|
      t.integer :user_id, null: false
      t.date :date, null: false
      t.integer :score, null: false
    end

    add_index :gamification_scores, %i[user_id date], unique: true
    add_index :gamification_scores, :date
  end
end
