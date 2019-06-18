# frozen_string_literal: true

class AddSecurityToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :secure, :boolean, default: false, null: false

    create_table :category_groups, force: true do |t|
      t.integer :category_id, null: false
      t.integer :group_id, null: false
      t.timestamps null: false
    end
  end
end
