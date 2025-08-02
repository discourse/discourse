# frozen_string_literal: true

class AddFullMoveToMovedPostRecords < ActiveRecord::Migration[7.2]
  def change
    add_column :moved_posts, :full_move, :boolean
  end
end
