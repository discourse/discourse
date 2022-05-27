# frozen_string_literal: true

class CreateUserStatuses < ActiveRecord::Migration[7.0]
  def up
    create_table :user_statuses, id: false do |t|
      t.integer :user_id, primary_key: true, null: false
      t.string :emoji, null: true
      t.string :description, null: false
      t.datetime :set_at, null: false
      t.datetime :ends_at, null: true
    end
  end

  def down
    drop_table :user_statuses
  end
end
