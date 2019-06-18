# frozen_string_literal: true

class AddIndexesToReviewables < ActiveRecord::Migration[5.2]
  def up
    remove_index :reviewables, :status
    add_index :reviewables, [:status, :created_at]
  end

  def down
    remove_index :reviewables, [:status, :created_at]
    add_index :reviewables, :status
  end
end
