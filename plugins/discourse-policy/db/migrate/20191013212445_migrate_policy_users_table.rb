# frozen_string_literal: true

class MigratePolicyUsersTable < ActiveRecord::Migration[5.2]
  def change
    create_table :policy_users do |t|
      t.integer :post_policy_id, null: false
      t.integer :user_id, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.datetime :expired_at
      t.string :version
      t.timestamps null: false
    end

    add_index :policy_users, %i[post_policy_id user_id]
  end
end
