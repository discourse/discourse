class AddAvgTimeToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :avg_time, :integer, null: true
    add_column :posts, :score, :float, null: true
  end
end
