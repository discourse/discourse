# frozen_string_literal: true
class CreateTagCustomFields < ActiveRecord::Migration[7.0]
  def change
    create_table :tag_custom_fields do |t|
      t.integer :tag_id, null: false
      t.string :name, limit: 256, null: false
      t.text :value
      t.timestamps null: false
    end

    add_index :tag_custom_fields, %i[tag_id name]
  end
end
