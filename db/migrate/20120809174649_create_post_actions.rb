class CreatePostActions < ActiveRecord::Migration[4.2]
  def up
    create_table :post_actions do |t|
      t.integer :post_id, null: false
      t.integer :user_id, null: false
      t.integer :post_action_type_id, null: false
      t.datetime :deleted_at
      t.timestamps null: false
    end

    add_index :post_actions, ["post_id"]

    # no support for this till rails 4
    execute 'create unique index idx_unique_actions on
      post_actions(user_id, post_action_type_id, post_id) where deleted_at is null'

  end
  def down
    drop_table :post_actions
  end
end
