# frozen_string_literal: true
class AddDiscourseSolvedTopicAnswers < ActiveRecord::Migration[8.0]
  def up
    create_table :discourse_solved_topic_answers do |t|
      t.bigint :solved_topic_id, null: false
      t.bigint :answer_post_id, null: false
      t.bigint :accepter_user_id, null: false
      t.timestamps null: false
    end

    add_index :discourse_solved_topic_answers, :solved_topic_id
    add_index :discourse_solved_topic_answers, :answer_post_id, unique: true

    execute <<~SQL
      INSERT INTO discourse_solved_topic_answers
        (solved_topic_id, answer_post_id, accepter_user_id, created_at, updated_at)
      SELECT id, answer_post_id, accepter_user_id, created_at, updated_at
        FROM discourse_solved_solved_topics
       WHERE answer_post_id IS NOT NULL
    SQL

    change_column :discourse_solved_solved_topics, :topic_id, :bigint

    # Allow null until post deploy migration when columns are removed
    change_column_null :discourse_solved_solved_topics, :answer_post_id, true
    change_column_null :discourse_solved_solved_topics, :accepter_user_id, true

    execute <<~SQL
      DROP TRIGGER IF EXISTS discourse_solved_sync_to_answers
        ON discourse_solved_solved_topics;
      DROP TRIGGER IF EXISTS discourse_solved_sync_delete_to_answers
        ON discourse_solved_solved_topics;
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION discourse_solved_sync_old_answers_to_new()
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
      CREATE TRIGGER discourse_solved_trigger_sync_old_answers_to_new
      AFTER INSERT OR UPDATE OF answer_post_id ON discourse_solved_solved_topics
      FOR EACH ROW
      WHEN (NEW.answer_post_id IS NOT NULL)
      EXECUTE FUNCTION discourse_solved_sync_old_answers_to_new();
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION discourse_solved_sync_old_answer_deletes_to_new()
      RETURNS TRIGGER AS $$
      BEGIN
        DELETE FROM discourse_solved_topic_answers WHERE solved_topic_id = OLD.id;
        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER discourse_solved_trigger_sync_old_answer_deletes_to_new
      AFTER DELETE ON discourse_solved_solved_topics
      FOR EACH ROW
      EXECUTE FUNCTION discourse_solved_sync_old_answer_deletes_to_new();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS discourse_solved_trigger_sync_old_answers_to_new
        ON discourse_solved_solved_topics;
      DROP TRIGGER IF EXISTS discourse_solved_trigger_sync_old_answer_deletes_to_new
        ON discourse_solved_solved_topics;
      DROP FUNCTION IF EXISTS discourse_solved_sync_old_answers_to_new();
      DROP FUNCTION IF EXISTS discourse_solved_sync_old_answer_deletes_to_new();
    SQL

    # Backfill legacy columns from topic_answers before restoring NOT NULL.
    # If a topic has multiple solutions (new feature), keep only the most recent.
    execute <<~SQL
      UPDATE discourse_solved_solved_topics st
         SET answer_post_id = latest.answer_post_id,
             accepter_user_id = latest.accepter_user_id
        FROM (
          SELECT DISTINCT ON (solved_topic_id)
                 solved_topic_id, answer_post_id, accepter_user_id
            FROM discourse_solved_topic_answers
           ORDER BY solved_topic_id, created_at DESC
        ) latest
       WHERE st.id = latest.solved_topic_id
    SQL

    # Drop any solved_topic rows with no remaining answers as a failsafe
    # before restoring the not null constraints
    execute <<~SQL
      DELETE FROM discourse_solved_solved_topics
       WHERE answer_post_id IS NULL OR accepter_user_id IS NULL
    SQL

    change_column :discourse_solved_solved_topics, :topic_id, :bigint
    change_column_null :discourse_solved_solved_topics, :accepter_user_id, false
    change_column_null :discourse_solved_solved_topics, :answer_post_id, false

    drop_table :discourse_solved_topic_answers
  end
end
