# frozen_string_literal: true

class AddDescriptionToExpressionTypes < ActiveRecord::Migration[4.2]
  def change
    add_column :expression_types, :description, :text, null: true
  end
end
