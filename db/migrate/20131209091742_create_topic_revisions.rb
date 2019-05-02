# frozen_string_literal: true

class CreateTopicRevisions < ActiveRecord::Migration[4.2]
  def up
    create_table :topic_revisions do |t|
      t.belongs_to :user
      t.belongs_to :topic
      t.text :modifications
      t.integer :number
      t.timestamps null: false
    end

    execute "INSERT INTO topic_revisions (user_id, topic_id, modifications, number, created_at, updated_at)
             SELECT user_id, versioned_id, modifications, number, created_at, updated_at
             FROM   versions
             WHERE  versioned_type = 'Topic'"

    change_table :topic_revisions do |t|
      t.index :topic_id
      t.index [:topic_id, :number]
    end
  end

  def down
    drop_table :topic_revisions
  end
end
