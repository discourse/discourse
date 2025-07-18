# frozen_string_literal: true

class AddDirectionToQuestionAnswerVotes < ActiveRecord::Migration[6.1]
  def up
    add_column :question_answer_votes, :direction, :string

    execute <<~SQL
    UPDATE question_answer_votes
    SET direction = 'up'
    SQL

    change_column_null :question_answer_votes, :direction, false
  end

  def down
    remove_column :question_answer_votes, :direction
  end
end
