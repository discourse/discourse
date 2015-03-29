class CreatePostTimingsUserIndex < ActiveRecord::Migration
  def change
    add_index :post_timings, :user_id
  end
end
