class RemoveUrlFromIncomingReferer < ActiveRecord::Migration
  def up
    remove_column :incoming_referers, :url
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
