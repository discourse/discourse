# frozen_string_literal: true

class CreatePostLocalizations < ActiveRecord::Migration[7.2]
  def change
    create_table :post_localizations do |t|
      t.integer :post_id, null: false
      t.integer :post_version, null: false
      t.string :locale, null: false, limit: 20
      t.text :raw, null: false
      t.text :cooked, null: false
      t.integer :localizer_user_id, null: false
      t.timestamps
    end

    add_index :post_localizations, :post_id
    add_index :post_localizations, %i[post_id locale], unique: true
  end
end
