# frozen_string_literal: true
class DropMultipleSolutionsDualWriteTriggers < ActiveRecord::Migration[8.0]
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
  end

  def down
    # Recreate the dual write triggers, as defined in AddDiscourseSolvedTopicAnswers
    execute <<~SQL
      DROP TRIGGER IF EXISTS solved_trigger_old_answers_to_new
        ON discourse_solved_solved_topics;
      DROP TRIGGER IF EXISTS solved_trigger_old_answer_deletes_to_new
        ON discourse_solved_solved_topics;
      DROP TRIGGER IF EXISTS solved_trigger_new_answers_to_old
        ON discourse_solved_solved_topics;
      DROP TRIGGER IF EXISTS solved_trigger_new_answer_deletes_to_old
        ON discourse_solved_solved_topics;
    SQL

    # Sync accepted answers in old code to the new model
    execute <<~SQL
      CREATE OR REPLACE FUNCTION solved_sync_old_answers_to_new()
      RETURNS TRIGGER AS $$
      BEGIN
        INSERT INTO discourse_solved_topic_answers
          (solved_topic_id, answer_post_id, accepter_user_id, created_at, updated_at)
        VALUES
          (NEW.id, NEW.answer_post_id, NEW.accepter_user_id, NEW.created_at, NEW.updated_at)
        ON CONFLICT (answer_post_id) DO UPDATE SET
          solved_topic_id = EXCLUDED.solved_topic_id,
          accepter_user_id = EXCLUDED.accepter_user_id,
          updated_at = now();
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER solved_trigger_old_answers_to_new
      AFTER INSERT OR UPDATE OF answer_post_id ON discourse_solved_solved_topics
      FOR EACH ROW
      WHEN (pg_trigger_depth() < 1 AND NEW.answer_post_id IS NOT NULL)
      EXECUTE FUNCTION solved_sync_old_answers_to_new();
    SQL

    # Sync unaccepted answers in old code to the new model
    execute <<~SQL
      CREATE OR REPLACE FUNCTION solved_sync_old_answer_deletes_to_new()
      RETURNS TRIGGER AS $$
      BEGIN
        DELETE FROM discourse_solved_topic_answers WHERE solved_topic_id = OLD.id;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER solved_trigger_old_answer_deletes_to_new
      AFTER DELETE ON discourse_solved_solved_topics
      FOR EACH ROW
      WHEN (pg_trigger_depth() < 1)
      EXECUTE FUNCTION solved_sync_old_answer_deletes_to_new();
    SQL

    # Sync accepted answers in new code to the old model (use newest accepted answer)
    execute <<~SQL
      CREATE OR REPLACE FUNCTION solved_sync_new_answers_to_old()
      RETURNS TRIGGER AS $$
      BEGIN
        UPDATE discourse_solved_solved_topics
          SET answer_post_id = NEW.answer_post_id,
              accepter_user_id = NEW.accepter_user_id
        WHERE id = NEW.solved_topic_id;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER solved_trigger_new_answers_to_old
      AFTER INSERT ON discourse_solved_topic_answers
      FOR EACH ROW
      WHEN (pg_trigger_depth() < 1)
      EXECUTE FUNCTION solved_sync_new_answers_to_old();
    SQL

    # Sync unaccepted answers in new code to the old model
    # If any TopicAnswers are left, store the newest one in the SolvedTopic.
    # If not, then the SolvedTopic is about to be deleted in either
    # UnacceptAnswer.unmark_as_solved or AcceptAnswer.revoke_previous_accepted_answer
    execute <<~SQL
      CREATE OR REPLACE FUNCTION solved_sync_new_answer_deletes_to_old()
      RETURNS TRIGGER AS $$
      BEGIN
        UPDATE discourse_solved_solved_topics sst
          SET answer_post_id = ta.answer_post_id,
              accepter_user_id = ta.accepter_user_id
          FROM (
            SELECT answer_post_id, accepter_user_id
              FROM discourse_solved_topic_answers
            WHERE solved_topic_id = OLD.solved_topic_id
            ORDER BY created_at DESC
            LIMIT 1
          ) ta
        WHERE sst.id = OLD.solved_topic_id;

        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER solved_trigger_new_answer_deletes_to_old
      AFTER DELETE ON discourse_solved_topic_answers
      FOR EACH ROW
      WHEN (pg_trigger_depth() < 1)
      EXECUTE FUNCTION solved_sync_new_answer_deletes_to_old();
    SQL
  end
end
