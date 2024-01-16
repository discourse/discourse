# frozen_string_literal: true

class CreateTopicHotScores < ActiveRecord::Migration[7.0]
  def change
    create_table :topic_hot_scores do |t|
      t.integer :topic_id, null: false
      t.float :score, null: false
      t.timestamps
    end

    add_index :topic_hot_scores, :topic_id, unique: true
    add_index :topic_hot_scores, %i[score topic_id], unique: true
  end
end
