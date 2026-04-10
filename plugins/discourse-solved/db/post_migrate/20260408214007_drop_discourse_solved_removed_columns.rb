# frozen_string_literal: true
class DropDiscourseSolvedRemovedColumns < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { discourse_solved_solved_topics: %i[answer_post_id accepter_user_id] }

  def up
    # Delete any answers that were migrated in the AddDiscourseSolvedTopicAnswers migration
    # but unaccepted in old code before this migration, so the SolvedTopic is gone
    execute <<~SQL
      DELETE FROM discourse_solved_topic_answers ta
      WHERE NOT EXISTS (
        SELECT 1 FROM discourse_solved_solved_topics st
        WHERE st.id = ta.solved_topic_id
      )
    SQL

    # Backfill any newly accepted answers since the AddDiscourseSolvedTopicAnswers migration
    # If answer_post_id is not null then the row was created by old code
    execute <<~SQL
      INSERT INTO discourse_solved_topic_answers
        (solved_topic_id, answer_post_id, accepter_user_id, created_at, updated_at)
      SELECT st.id, st.answer_post_id, st.accepter_user_id, st.created_at, st.updated_at
        FROM discourse_solved_solved_topics st
       WHERE st.answer_post_id IS NOT NULL
         AND NOT EXISTS (
           SELECT 1 FROM discourse_solved_topic_answers ta
            WHERE ta.solved_topic_id = st.id and ta.answer_post_id = st.answer_post_id
         )
      ON CONFLICT (answer_post_id) DO NOTHING
    SQL

    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
