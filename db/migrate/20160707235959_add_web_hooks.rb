class AddWebHooks < ActiveRecord::Migration
  def change
    create_table :web_hook_event_types do |t|
      t.string :name, null: false
    end

    create_table :web_hooks do |t|
      t.string  :payload_url, null: false
      t.integer :content_type, default: 1, null: false
      t.integer :last_delivery_status, default: 1, null: false
      t.integer :status, default: 1, null: false
      t.string  :secret, default: ''
      t.boolean :wildcard_web_hook, default: false, null: false

      t.boolean :verify_certificate, default: true, null: false
      t.boolean :active, default: false, null: false

      t.timestamps
    end

    create_join_table :web_hooks, :web_hook_event_types
    create_join_table :web_hooks, :groups
    create_join_table :web_hooks, :categories

    add_index :web_hook_event_types_hooks, [:web_hook_event_type_id, :web_hook_id],
              name: 'idx_web_hook_event_types_hooks_on_ids',
              unique: true
    add_index :categories_web_hooks, [:web_hook_id, :category_id], unique: true
    add_index :groups_web_hooks, [:web_hook_id, :group_id], unique: true
  end
end
