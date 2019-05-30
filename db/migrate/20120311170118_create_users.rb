# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[4.2]
  def change
    create_table :users do |t|
      t.string :username, limit: 20, null: false
      t.string :avatar_url, null: false
      t.timestamps null: false
    end
  end
end
