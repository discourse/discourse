# frozen_string_literal: true
#
class AddIndexForDiscourseSolvedTopics < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :discourse_solved_solved_topics,
                 :topic_id,
                 algorithm: :concurrently,
                 unique: true,
                 if_exists: true
    remove_index :discourse_solved_solved_topics,
                 :answer_post_id,
                 algorithm: :concurrently,
                 unique: true,
                 if_exists: true

    add_index :discourse_solved_solved_topics, :topic_id, unique: true, algorithm: :concurrently
    add_index :discourse_solved_solved_topics,
              :answer_post_id,
              unique: true,
              algorithm: :concurrently
  end
end
