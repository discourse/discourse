class CreateReviewableClaimedTopics < ActiveRecord::Migration[5.2]
  def change
    create_table :reviewable_claimed_topics do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.timestamps
    end
    add_index :reviewable_claimed_topics, :topic_id, unique: true
  end
end
