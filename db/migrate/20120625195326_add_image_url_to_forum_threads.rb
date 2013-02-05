class AddImageUrlToForumThreads < ActiveRecord::Migration
  def change
    add_column :forum_threads, :image_url, :string
  end
end
