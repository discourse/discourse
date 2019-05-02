# frozen_string_literal: true

class CreateGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :groups, force: true do |t|
      t.string :name, null: false
      t.timestamps null: false
    end
  end
end
