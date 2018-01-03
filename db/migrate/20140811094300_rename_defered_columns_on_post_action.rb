class RenameDeferedColumnsOnPostAction < ActiveRecord::Migration[4.2]
  def change
    rename_column :post_actions, :defered_by_id, :deferred_by_id
    rename_column :post_actions, :defered_at, :deferred_at
  end
end
