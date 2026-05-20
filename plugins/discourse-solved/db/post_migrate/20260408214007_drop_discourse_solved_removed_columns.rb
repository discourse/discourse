# frozen_string_literal: true
class DropDiscourseSolvedRemovedColumns < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { discourse_solved_solved_topics: %i[answer_post_id accepter_user_id] }

  def up
    execute <<~SQL
      DROP TRIGGER IF EXISTS solved_trigger_old_answers_to_new
        ON discourse_solved_solved_topics;
      DROP TRIGGER IF EXISTS solved_trigger_old_answer_deletes_to_new
        ON discourse_solved_solved_topics;
      DROP TRIGGER IF EXISTS solved_trigger_new_answers_to_old
        ON discourse_solved_topic_answers;
      DROP TRIGGER IF EXISTS solved_trigger_new_answer_deletes_to_old
        ON discourse_solved_topic_answers;
      DROP FUNCTION IF EXISTS solved_sync_old_answers_to_new();
      DROP FUNCTION IF EXISTS solved_sync_old_answer_deletes_to_new();
      DROP FUNCTION IF EXISTS solved_sync_new_answers_to_old();
      DROP FUNCTION IF EXISTS solved_sync_new_answer_deletes_to_old();
    SQL

    # Failsafe to backfill answers which weren't caught by the triggers just in case
    execute <<~SQL
      INSERT INTO discourse_solved_topic_answers
        (solved_topic_id, answer_post_id, accepter_user_id, created_at, updated_at)
      SELECT st.id, st.answer_post_id, st.accepter_user_id, st.created_at, st.updated_at
        FROM discourse_solved_solved_topics st
       WHERE st.answer_post_id IS NOT NULL
         AND NOT EXISTS (
           SELECT 1 FROM discourse_solved_topic_answers ta
            WHERE ta.solved_topic_id = st.id
              AND ta.answer_post_id = st.answer_post_id
         )
      ON CONFLICT (answer_post_id) DO NOTHING
    SQL

    # Failsafe to clean up any orphaned topic_answers
    execute <<~SQL
      DELETE FROM discourse_solved_topic_answers ta
       WHERE NOT EXISTS (
         SELECT 1 FROM discourse_solved_solved_topics st WHERE st.id = ta.solved_topic_id
       )
    SQL

    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
