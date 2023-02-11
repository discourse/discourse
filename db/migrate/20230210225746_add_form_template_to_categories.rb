# frozen_string_literal: true

class AddFormTemplateToCategories < ActiveRecord::Migration[7.0]
  def change
    add_column :categories, :form_template, :json, null: true
  end
end
