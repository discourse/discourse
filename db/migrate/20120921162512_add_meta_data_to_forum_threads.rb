class AddMetaDataToForumThreads < ActiveRecord::Migration
  def change
    execute "CREATE EXTENSION IF NOT EXISTS hstore"
    add_column :forum_threads, :meta_data, :hstore
  end
end
