class FixIncomingLinks < ActiveRecord::Migration
  def up
    execute "DROP INDEX incoming_index"
    add_column :incoming_links, :post_id, :integer
    remove_column :incoming_links, :updated_at
    remove_column :incoming_links, :url

    execute "UPDATE incoming_links l SET post_id = (
      SELECT p.id FROM posts p WHERE p.topic_id = l.topic_id AND p.post_number = l.post_number
    )"

    execute "DELETE FROM incoming_links WHERE post_id IS NULL"
    change_column :incoming_links, :post_id, :integer, null: false

    add_index :incoming_links, :post_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
