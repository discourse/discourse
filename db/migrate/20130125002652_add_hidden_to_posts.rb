class AddHiddenToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :hidden, :boolean, null: false, default: false
    add_column :posts, :hidden_reason_id, :integer
  end
end
