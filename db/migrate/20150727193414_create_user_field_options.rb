# frozen_string_literal: true

class CreateUserFieldOptions < ActiveRecord::Migration[4.2]
  def change
    create_table :user_field_options, force: true do |t|
      t.integer :user_field_id, null: false
      t.string :value, null: false
      t.timestamps null: false
    end
  end
end
