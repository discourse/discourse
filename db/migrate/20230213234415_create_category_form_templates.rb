# frozen_string_literal: true

class CreateCategoryFormTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :category_form_templates do |t|
      t.references :category, foreign_key: true
      t.references :form_template, foreign_key: true

      t.timestamps
    end
  end
end
