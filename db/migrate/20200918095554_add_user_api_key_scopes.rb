# frozen_string_literal: true

class AddUserApiKeyScopes < ActiveRecord::Migration[6.0]
  def change
    create_table :user_api_key_scopes do |t|
      t.integer :user_api_key_id, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :user_api_key_scopes, :user_api_key_id

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO user_api_key_scopes
          (
            user_api_key_id,
            name,
            created_at,
            updated_at
          )
          SELECT
            user_api_keys.id,
            unnest(user_api_keys.scopes),
            created_at,
            updated_at
          FROM user_api_keys
        SQL

        Migration::SafeMigrate.disable!
        change_column_null :user_api_keys, :scopes, true
        change_column_default :user_api_keys, :scopes, nil
        Migration::SafeMigrate.enable!

        Migration::ColumnDropper.mark_readonly(:user_api_keys, :scopes)
      end

      dir.down do
        change_column_null :user_api_keys, :scopes, false
        change_column_default :user_api_keys, :scopes, []
        Migration::ColumnDropper.drop_readonly(:user_api_keys, :scopes)
      end
    end
  end
end
