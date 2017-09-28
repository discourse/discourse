class CreateInvites < ActiveRecord::Migration[4.2]
  def change
    create_table :invites do |t|
      t.string :invite_key, null: false, limit: 32
      t.string :email, null: false
      t.integer :invited_by_id, null: false
      t.integer :user_id, null: true
      t.timestamp :redeemed_at, null: true
      t.timestamps null: false
    end

    add_index :invites, :invite_key, unique: true
    add_index :invites, [:email, :invited_by_id], unique: true
  end
end
