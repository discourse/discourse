# frozen_string_literal: true

class CreateCategoryFormTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :category_form_templates do |t|
      t.references :category, null: false
      t.references :form_template, null: false

      t.timestamps
    end
  end
end
