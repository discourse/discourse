# frozen_string_literal: true

class CreateFormTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :form_templates do |t|
      t.string :name, null: false
      t.string :template, null: false

      t.timestamps null: false
    end

    add_index :form_templates, :name, unique: true
  end
end
