# frozen_string_literal: true

class AddDeletedAtToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :deleted_at, :datetime
  end
end
