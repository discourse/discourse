class CreatePostTimingsUserIndex < ActiveRecord::Migration[4.2]
  def change
    add_index :post_timings, :user_id
  end
end
