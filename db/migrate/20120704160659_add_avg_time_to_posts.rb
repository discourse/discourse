# frozen_string_literal: true

class AddAvgTimeToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :avg_time, :integer, null: true
    add_column :posts, :score, :float, null: true
  end
end
