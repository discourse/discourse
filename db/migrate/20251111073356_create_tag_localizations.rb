# frozen_string_literal: true

class CreateTagLocalizations < ActiveRecord::Migration[8.0]
  def change
    create_table :tag_localizations do |t|
      t.references :tag, null: false
      t.string :locale, limit: 20, null: false
      t.string :name, null: false
      t.string :description, null: true, limit: 1000

      t.timestamps null: false
    end

    add_index :tag_localizations, %i[tag_id locale], unique: true
  end
end
