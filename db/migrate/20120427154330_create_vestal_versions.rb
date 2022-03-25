# frozen_string_literal: true

class CreateVestalVersions < ActiveRecord::Migration[4.2]
  def self.up
    create_table :versions do |t|
      t.integer :versioned_id, null: false
      t.string :versioned_type, null: false
      t.integer :user_id, null: false
      t.string :user_type, null: false
      t.string  :user_name
      t.text    :modifications
      t.integer :number
      t.integer :reverted_from
      t.string  :tag

      t.timestamps null: false
    end

    change_table :versions do |t|
      t.index [:versioned_id, :versioned_type]
      t.index [:user_id, :user_type]
      t.index :user_name
      t.index :number
      t.index :tag
      t.index :created_at
    end
  end

  def self.down
    drop_table :versions
  end
end
