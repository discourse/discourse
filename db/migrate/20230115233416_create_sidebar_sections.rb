# frozen_string_literal: true

class CreateSidebarSections < ActiveRecord::Migration[7.0]
  def change
    create_table :sidebar_sections do |t|
      t.integer :user_id, null: false
      t.string :title, null: false
      t.timestamps
    end

    add_index :sidebar_sections, %i[user_id title], unique: true
  end
end
