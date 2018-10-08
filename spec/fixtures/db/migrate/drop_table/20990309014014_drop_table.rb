class DropTable < ActiveRecord::Migration[5.1]
  def up
    drop_table :users
  end

  def down
    raise "not tested"
  end
end
