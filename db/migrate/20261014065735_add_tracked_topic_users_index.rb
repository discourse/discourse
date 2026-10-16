# frozen_string_literal: true

class AddTrackedTopicUsersIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "index_topic_users_on_user_id_and_topic_id_tracked"

  def up
    remove_index :topic_users, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :topic_users,
              %i[user_id topic_id],
              name: INDEX_NAME,
              where: "notification_level >= 2",
              algorithm: :concurrently
  end

  def down
    remove_index :topic_users, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
