class CreatePostTimings < ActiveRecord::Migration[4.2]
  def change
    create_table :post_timings do |t|
      t.integer :thread_id, null: false
      t.integer :post_number, null: false
      t.integer :user_id, null: false
      t.integer :msecs, null: false
    end

    add_index :post_timings, [:thread_id, :post_number]
    add_index :post_timings, [:thread_id, :post_number, :user_id], unique: true
  end
end
