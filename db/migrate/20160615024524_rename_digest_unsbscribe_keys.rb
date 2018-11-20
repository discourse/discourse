class RenameDigestUnsbscribeKeys < ActiveRecord::Migration[4.2]
  def up
    rename_table :digest_unsubscribe_keys, :unsubscribe_keys

    add_column :unsubscribe_keys, :unsubscribe_key_type, :string
    add_column :unsubscribe_keys, :topic_id, :int
    add_column :unsubscribe_keys, :post_id, :int

    execute "UPDATE unsubscribe_keys SET unsubscribe_key_type = 'digest' WHERE unsubscribe_key_type IS NULL"
  end

  def down
    remove_column :unsubscribe_keys, :unsubscribe_key_type
    remove_column :unsubscribe_keys, :topic_id
    remove_column :unsubscribe_keys, :post_id

    rename_table :unsubscribe_keys, :digest_unsubscribe_keys
  end
end
