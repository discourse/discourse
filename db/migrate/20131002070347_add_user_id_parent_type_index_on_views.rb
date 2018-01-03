class AddUserIdParentTypeIndexOnViews < ActiveRecord::Migration[4.2]
  def change
    add_index :views, [:user_id, :parent_type, :parent_id]
  end
end
