# frozen_string_literal: true

class ChangeTemplateToText < ActiveRecord::Migration[7.0]
  def change
    change_column :form_templates, :template, :text
  end
end
