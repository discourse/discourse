class DropUnreadTrackingColumns < ActiveRecord::Migration[4.2]
  def up
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
