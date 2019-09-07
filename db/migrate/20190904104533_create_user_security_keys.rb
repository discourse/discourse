# frozen_string_literal: true

class CreateUserSecurityKeys < ActiveRecord::Migration[5.2]
  def up
    create_table :user_security_keys do |t|
      t.references :user, null: false, index: true, foreign_key: true
      t.string :credential_id, null: false
      t.string :public_key, null: false, index: true
      t.integer :factor_type, null: false, default: 0, index: true
      t.boolean :enabled, null: false, default: true
      t.string :name, null: false
      t.datetime :last_used

      t.timestamps
    end

    add_index :user_security_keys, :credential_id, unique: true
    add_index :user_security_keys, :last_used
  end

  def down
    if column_exists?(:user_second_factors, :user_security_key_id)
      remove_column(:user_second_factors, :user_security_key_id)
    end

    if table_exists?(:user_second_factors)
      drop_table(:user_second_factors)
    end
  end
end
