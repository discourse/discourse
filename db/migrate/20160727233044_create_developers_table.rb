class CreateDevelopersTable < ActiveRecord::Migration[4.2]
  def change
    create_table :developers do |t|
      t.integer :user_id, null: false
    end
  end
end
