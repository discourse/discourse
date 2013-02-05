class AddMetaDataToForumThreads < ActiveRecord::Migration
  def change
    add_column :forum_threads, :meta_data, :hstore
  end
end
