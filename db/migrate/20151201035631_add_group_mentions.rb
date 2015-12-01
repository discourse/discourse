class AddGroupMentions < ActiveRecord::Migration
  def change
    create_table :group_mentions do |t|
      t.integer :post_id
      t.integer :group_id
      t.timestamps
    end

    add_index :group_mentions, [:post_id, :group_id], unique: true
    add_index :group_mentions, [:group_id, :post_id], unique: true
  end
end
