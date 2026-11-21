# frozen_string_literal: true
class AddOutputTemplateToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :output_template, :text
  end
end
