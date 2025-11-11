# frozen_string_literal: true

class AddPolymorphicColumnsToQuestionAnswerVotes < ActiveRecord::Migration[6.1]
  def up
    add_column :question_answer_votes, :votable_type, :string
    add_column :question_answer_votes, :votable_id, :integer

    execute <<~SQL
    UPDATE question_answer_votes
    SET votable_type = 'Post', votable_id = question_answer_votes.post_id
    SQL

    change_column_null :question_answer_votes, :votable_type, false
    change_column_null :question_answer_votes, :votable_id, false

    begin
      # At this point in time, this plugin has not been publicly released so just dropping it
      Migration::SafeMigrate.disable!
      remove_column :question_answer_votes, :post_id
    ensure
      Migration::SafeMigrate.enable!
    end

    add_index :question_answer_votes,
              %i[votable_type votable_id user_id],
              unique: true,
              name: "idx_votable_user_id"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
