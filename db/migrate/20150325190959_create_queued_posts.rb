class CreateQueuedPosts < ActiveRecord::Migration
  def change
    create_table :queued_posts, force: true do |t|
      t.string     :queue, null: false
      t.integer    :state, null: false
      t.integer    :user_id, null: false
      t.text       :raw, null: false
      t.json       :post_options, null: false
      t.integer    :topic_id
      t.integer    :approved_by_id
      t.timestamp  :approved_at
      t.integer    :rejected_by_id
      t.timestamp  :rejected_at
      t.timestamps
    end

    add_index :queued_posts, [:queue, :state, :created_at], name: 'by_queue_status'
    add_index :queued_posts, [:topic_id, :queue, :state, :created_at], name: 'by_queue_status_topic'
  end
end
