class RemoveUrlFromIncomingReferer < ActiveRecord::Migration[4.2]
  def up
    remove_column :incoming_referers, :url
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
