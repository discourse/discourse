# frozen_string_literal: true

class CreateApiKeys < ActiveRecord::Migration[4.2]

  def up
    create_table :api_keys do |t|
      t.string :key, limit: 64, null: false
      t.integer :user_id, null: true
      t.integer :created_by_id
      t.timestamps null: false
    end

    add_index :api_keys, :key
    add_index :api_keys, :user_id, unique: true

    execute "INSERT INTO api_keys (key, created_at, updated_at) SELECT value, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM site_settings WHERE name = 'api_key'"
    execute "DELETE FROM site_settings WHERE name = 'api_key'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration.new
  end

end
