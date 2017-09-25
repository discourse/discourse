class AddUnreadTrackingColumns < ActiveRecord::Migration[4.2]
  def up
    # no op, no need to create all data, next migration will delete it
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
