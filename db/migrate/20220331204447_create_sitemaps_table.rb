# frozen_string_literal: true

class CreateSitemapsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :sitemaps, if_not_exists: true do |t|
      t.string :name, null: false
      t.datetime :last_posted_at, null: false
      t.boolean :enabled, null: false, default: true
    end

    add_index :sitemaps, :name, unique: true, if_not_exists: true
  end
end
