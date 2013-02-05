class CreateUserOpenIds < ActiveRecord::Migration
  def change
    create_table :user_open_ids do |t|
      t.integer :user_id
      t.string :email
      t.string :url
      t.timestamps
    end

    add_index :user_open_ids, [:url]

  end
end
