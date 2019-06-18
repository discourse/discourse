# frozen_string_literal: true

class RemoveForumId < ActiveRecord::Migration[4.2]
  def up
    remove_column 'forum_threads', 'forum_id'
    remove_column 'categories', 'forum_id'
  end

  def down
    raise 'not reversible'
  end
end
