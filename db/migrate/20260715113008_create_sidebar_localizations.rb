# frozen_string_literal: true
class CreateSidebarLocalizations < ActiveRecord::Migration[8.0]
  def change
    add_column :sidebar_sections, :locale, :string, limit: 20
    add_column :sidebar_urls, :locale, :string, limit: 20

    create_table :sidebar_section_localizations do |t|
      t.references :sidebar_section, null: false
      t.string :locale, limit: 20, null: false
      t.string :title, limit: 30, null: false

      t.timestamps null: false
    end

    add_index :sidebar_section_localizations, %i[sidebar_section_id locale], unique: true

    create_table :sidebar_url_localizations do |t|
      t.references :sidebar_url, null: false
      t.string :locale, limit: 20, null: false
      t.string :name, limit: 80, null: false

      t.timestamps null: false
    end

    add_index :sidebar_url_localizations, %i[sidebar_url_id locale], unique: true
  end
end
