# frozen_string_literal: true

class AddImageUrlToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :image_url, :string
  end
end
