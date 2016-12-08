class CreateUserFirsts < ActiveRecord::Migration
  def change
    create_table :user_firsts, force: true do |t|
      t.integer :user_id, null: false
      t.integer :first_type, null: false
      t.integer :post_id
      t.datetime :created_at, null: false
    end

    add_index :user_firsts, [:user_id, :first_type], unique: true
  end
end
