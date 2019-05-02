# frozen_string_literal: true

class CreateTranslationOverrides < ActiveRecord::Migration[4.2]
  def change
    create_table :translation_overrides, force: true do |t|
      t.string :locale, length: 30, null: false
      t.string :translation_key, null: false
      t.string :value, null: false
      t.timestamps null: false
    end

    add_index :translation_overrides, [:locale, :translation_key], unique: true
  end
end
