# frozen_string_literal: true

class CreateSidebarUrl < ActiveRecord::Migration[7.0]
  def change
    create_table :sidebar_urls do |t|
      t.string :name, null: false
      t.string :value, null: false
      t.timestamps
    end
  end
end
