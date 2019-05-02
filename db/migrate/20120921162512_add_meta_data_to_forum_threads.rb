# frozen_string_literal: true

class AddMetaDataToForumThreads < ActiveRecord::Migration[4.2]
  def change
    execute "CREATE EXTENSION IF NOT EXISTS hstore"
    add_column :forum_threads, :meta_data, :hstore
  end
end
