# frozen_string_literal: true

class CreateJavascriptCaches < ActiveRecord::Migration[5.2]
  def change
    create_table :javascript_caches do |t|
      t.references :theme_field, null: false
      t.string :digest, null: true, index: true
      t.text :content, null: false
      t.timestamps
    end
  end
end
