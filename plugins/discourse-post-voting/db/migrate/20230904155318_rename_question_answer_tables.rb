# frozen_string_literal: true

require "migration/table_dropper"

class RenameQuestionAnswerTables < ActiveRecord::Migration[7.0]
  def up
    unless table_exists?(:post_voting_comments)
      Migration::TableDropper.read_only_table(:question_answer_comments)
      execute <<~SQL
        CREATE TABLE post_voting_comments
        (LIKE question_answer_comments INCLUDING ALL);
      SQL

      execute <<~SQL
        INSERT INTO post_voting_comments
        SELECT *
        FROM question_answer_comments
      SQL

      execute <<~SQL
        ALTER SEQUENCE question_answer_comments_id_seq
        RENAME TO post_voting_comments_id_seq
      SQL

      execute <<~SQL
        ALTER SEQUENCE post_voting_comments_id_seq
        OWNED BY post_voting_comments.id
      SQL

      add_index :post_voting_comments, :post_id
      add_index :post_voting_comments, :user_id
      add_index :post_voting_comments, :deleted_by_id, where: "deleted_by_id IS NOT NULL"
    end

    unless table_exists?(:post_voting_votes)
      Migration::TableDropper.read_only_table(:question_answer_votes)
      execute <<~SQL
        CREATE TABLE post_voting_votes
        (LIKE question_answer_votes INCLUDING ALL);
      SQL

      execute <<~SQL
        INSERT INTO post_voting_votes
        SELECT *
        FROM question_answer_votes
      SQL

      execute <<~SQL
        ALTER SEQUENCE question_answer_votes_id_seq
        RENAME TO post_voting_votes_id_seq
      SQL

      execute <<~SQL
        ALTER SEQUENCE post_voting_votes_id_seq
        OWNED BY post_voting_votes.id
      SQL

      execute <<~SQL
        UPDATE post_voting_votes
        SET votable_type = 'PostVotingComment'
        WHERE votable_type = 'QuestionAnswerComment'
      SQL

      add_index :post_voting_votes,
                %i[votable_type votable_id user_id],
                unique: true,
                name: "post_voting_votes_votable_type_and_votable_id_and_user_id_idx"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
