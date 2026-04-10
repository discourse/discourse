# frozen_string_literal: true
class AddDiscourseSolvedTopicAnswers < ActiveRecord::Migration[8.0]
  def up
    create_table :discourse_solved_topic_answers do |t|
      t.integer :solved_topic_id, null: false
      t.integer :answer_post_id, null: false
      t.integer :accepter_user_id, null: false
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

    # Allow null until post deploy migration when columns are removed
    change_column_null :discourse_solved_solved_topics, :answer_post_id, true
    change_column_null :discourse_solved_solved_topics, :accepter_user_id, true
  end

  def down
    change_column_null :discourse_solved_solved_topics, :accepter_user_id, false
    change_column_null :discourse_solved_solved_topics, :answer_post_id, false
    drop_table :discourse_solved_topic_answers
  end
end
