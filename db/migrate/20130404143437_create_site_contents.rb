# frozen_string_literal: true

class CreateSiteContents < ActiveRecord::Migration[4.2]
  def change
    create_table :site_contents, force: true, id: false do |t|
      t.string :content_type, null: false
      t.text :content, null: false
      t.timestamps null: false
    end
    add_index :site_contents, :content_type, unique: true
  end
end
