# frozen_string_literal: true

class RemoveDuplicatesFromDiscourseSolvedSolvedTopics < ActiveRecord::Migration[7.2]
  def up
    # remove duplicates on answer_post_id based on earliest created_at
    DB.exec(<<~SQL)
      DELETE FROM discourse_solved_solved_topics
      WHERE id NOT IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY answer_post_id ORDER BY created_at) as row_num
          FROM discourse_solved_solved_topics
        ) t WHERE row_num = 1
      )
    SQL

    # remove duplicates on topic_id based on earliest created_at
    DB.exec(<<~SQL)
      DELETE FROM discourse_solved_solved_topics
      WHERE id NOT IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY topic_id ORDER BY created_at) as row_num
          FROM discourse_solved_solved_topics
        ) t WHERE row_num = 1
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
