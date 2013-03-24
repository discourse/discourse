class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :username, limit: 20, null: false
      t.string :avatar_url, null: false
      t.timestamps
    end
  end
end
