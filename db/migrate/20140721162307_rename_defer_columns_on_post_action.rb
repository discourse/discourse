class RenameDeferColumnsOnPostAction < ActiveRecord::Migration[4.2]
  def up
    rename_column :post_actions, :defer_by, :defered_by_id

    add_column :post_actions, :defered_at, :datetime
    execute "UPDATE post_actions SET defered_at = updated_at WHERE defer = 't'"
    remove_column :post_actions, :defer
  end

  def down
    rename_column :post_actions, :defered_by_id, :defer_by

    add_column :post_actions, :defer, :boolean
    execute "UPDATE post_actions SET defer = 't' WHERE defered_at IS NOT NULL"
    remove_column :post_actions, :defered_at
  end
end
