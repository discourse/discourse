# frozen_string_literal: true

class RemoveLimitsFromFormTemplates < ActiveRecord::Migration[7.1]
  def change
    change_column :form_templates, :name, :string, limit: nil
    change_column :form_templates, :template, :text, limit: nil
  end
end
