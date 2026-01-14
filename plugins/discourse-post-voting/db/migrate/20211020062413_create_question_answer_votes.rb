# frozen_string_literal: true

class CreateQuestionAnswerVotes < ActiveRecord::Migration[6.1]
  def up
    create_table :question_answer_votes do |t|
      t.integer :post_id, null: false
      t.integer :user_id, null: false
      t.datetime :created_at, null: false
    end

    add_index :question_answer_votes, %i[post_id user_id], unique: true

    add_column :posts, :qa_vote_count, :integer, default: 0, null: true
  end

  def down
    drop_table :question_answer_votes
    remove_index :question_answer_votes, %i[post_id user_id]
  end
end
