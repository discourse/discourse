# frozen_string_literal: true

class CreateDismissedTopicUsersTable < ActiveRecord::Migration[6.0]
  def change
    create_table :dismissed_topic_users do |t|
      t.integer :user_id
      t.integer :topic_id
      t.datetime :created_at
    end
    add_index :dismissed_topic_users, %i[user_id topic_id], unique: true
  end
end
