# frozen_string_literal: true

class CreateUserOpenIds < ActiveRecord::Migration[4.2]
  def change
    create_table :user_open_ids do |t|
      t.integer :user_id
      t.string :email
      t.string :url
      t.timestamps null: false
    end

    add_index :user_open_ids, [:url]

  end
end
