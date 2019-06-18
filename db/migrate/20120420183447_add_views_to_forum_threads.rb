# frozen_string_literal: true

class AddViewsToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :views, :integer, default: 0, null: false
  end
end
