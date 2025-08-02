# frozen_string_literal: true

class AddLockedByToPosts < ActiveRecord::Migration[5.1]
  def change
    add_column :posts, :locked_by_id, :integer
  end
end
