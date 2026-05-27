# frozen_string_literal: true
class CreateDiscourseSolvedSharedIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_solved_shared_issues do |t|
      t.integer :topic_id, null: false
      t.integer :user_id, null: false
      t.timestamps
    end

    add_index :discourse_solved_shared_issues, %i[topic_id user_id], unique: true
    add_index :discourse_solved_shared_issues, %i[user_id topic_id]
  end
end
