class RemoveOneboxesFromDb < ActiveRecord::Migration
  def up
    drop_table :post_onebox_renders
    drop_table :onebox_renders
  end

  def down
  end
end
