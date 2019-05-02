# frozen_string_literal: true

class CreateSites < ActiveRecord::Migration[4.2]
  def change
    create_table :sites  do |t|
      t.string :title, limit: 100, null: false
      t.timestamps null: false
    end
  end
end
