class AddUserIdParentTypeIndexOnViews < ActiveRecord::Migration
  def change
    add_index :views, [:user_id,:parent_type,:parent_id]
  end
end
