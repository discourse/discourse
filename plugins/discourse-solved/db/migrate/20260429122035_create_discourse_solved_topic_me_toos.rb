# frozen_string_literal: true
class CreateDiscourseSolvedTopicMeToos < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_solved_topic_me_toos do |t|
      t.integer :topic_id, null: false
      t.integer :user_id, null: false
      t.timestamps
    end

    add_index :discourse_solved_topic_me_toos, %i[topic_id user_id], unique: true
    add_index :discourse_solved_topic_me_toos, :topic_id
  end
end
