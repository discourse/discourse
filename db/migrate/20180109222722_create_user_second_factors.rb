class CreateUserSecondFactors < ActiveRecord::Migration[5.1]
  def change
    create_table :user_second_factors do |t|
      t.integer :user_id, null: false
      t.string :method
      t.string :data
      t.boolean :enabled, null: false, default: false
      t.timestamp :last_used
      t.timestamps
    end
  end
end
