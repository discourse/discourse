# frozen_string_literal: true
#
class CreateDiscourseSolvedSolvedTopics < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_solved_solved_topics do |t|
      t.integer :topic_id, null: false
      t.integer :answer_post_id, null: false
      t.integer :accepter_user_id, null: false
      t.integer :topic_timer_id
      t.timestamps
    end
  end
end
