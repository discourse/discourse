# frozen_string_literal: true

class AddQaVoteCountToQuestionAnswerComments < ActiveRecord::Migration[6.1]
  def up
    add_column :question_answer_comments, :qa_vote_count, :integer, default: 0
    execute "ALTER TABLE question_answer_comments ADD CONSTRAINT qa_vote_count_positive CHECK (qa_vote_count >= 0)"
  end

  def down
    execute "ALTER TABLE question_answer_comments DROP CONSTRAINT qa_vote_count_positive"
    remove_column :question_answer_comments, :qa_vote_count
  end
end
