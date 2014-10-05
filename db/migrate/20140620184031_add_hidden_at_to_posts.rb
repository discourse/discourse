class AddHiddenAtToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :hidden_at, :timestamp
  end
end
