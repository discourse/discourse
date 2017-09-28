class AddGroupMentions < ActiveRecord::Migration[4.2]
  def change
    create_table :group_mentions do |t|
      t.integer :post_id
      t.integer :group_id
      t.timestamps null: false
    end

    add_index :group_mentions, [:post_id, :group_id], unique: true
    add_index :group_mentions, [:group_id, :post_id], unique: true
  end
end
