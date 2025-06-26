# frozen_string_literal: true

class AddInviteCustomFields < ActiveRecord::Migration[7.2]
  def change
    create_table :invite_custom_fields do |t|
      t.integer :invite_id, null: false
      t.string :name, limit: 256, null: false
      t.text :value
      t.timestamps null: false
    end

    add_index :invite_custom_fields, %i[invite_id name]
  end
end
