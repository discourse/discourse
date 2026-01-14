# frozen_string_literal: true

class CreateCategoryLocalizationTable < ActiveRecord::Migration[7.2]
  def change
    create_table :category_localizations do |t|
      t.references :category, null: false
      t.string :locale, limit: 20, null: false
      t.string :name, limit: 50, null: false
      t.text :description, null: true

      t.timestamps null: false
    end

    add_index :category_localizations, %i[category_id locale], unique: true
  end
end
