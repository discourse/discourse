class CreateDevelopersTable < ActiveRecord::Migration
  def change
    create_table :developers do |t|
      t.integer :user_id, null: false
    end
  end
end
