class CreateUserVisits < ActiveRecord::Migration
  def change
    create_table :user_visits do |t|
      t.integer :user_id, null: false
      t.date :visited_at, null: false
    end

    add_index :user_visits, [:user_id, :visited_at], unique: true
  end
end
