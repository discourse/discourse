class AddHiddenAtToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :hidden_at, :timestamp
  end
end
