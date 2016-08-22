class AddUserApiKeys < ActiveRecord::Migration
  def change
    create_table :user_api_keys do |t|
      t.integer :user_id, null: false
      t.string :client_id, null: false
      t.string :key, null: false
      t.string :application_name, null: false
      t.boolean :read, null: false
      t.boolean :write, null: false
      t.boolean :push, null: false
      t.string :push_url
      t.timestamps
    end

    add_index :user_api_keys, [:key], unique: true
    add_index :user_api_keys, [:user_id]
    add_index :user_api_keys, [:client_id]
  end
end
