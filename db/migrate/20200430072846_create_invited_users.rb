# frozen_string_literal: true

class CreateInvitedUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :invited_users do |t|
      t.integer :user_id
      t.integer :invite_id, null: false
      t.datetime :redeemed_at
      t.timestamps null: false
    end

    add_index :invited_users, :invite_id
    add_index :invited_users, [:user_id, :invite_id], unique: true, where: 'user_id IS NOT NULL'
  end
end
