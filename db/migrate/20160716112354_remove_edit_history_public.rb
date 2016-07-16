class RemoveEditHistoryPublic < ActiveRecord::Migration
  def up
    remove_column :user_options, :edit_history_public
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
