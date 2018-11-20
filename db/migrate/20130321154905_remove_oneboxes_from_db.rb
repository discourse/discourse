class RemoveOneboxesFromDb < ActiveRecord::Migration[4.2]
  def up
    drop_table :post_onebox_renders
    drop_table :onebox_renders
  end

  def down
  end
end
