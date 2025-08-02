# frozen_string_literal: true

class AddFlagToExpressionTypes < ActiveRecord::Migration[4.2]
  def change
    add_column :expression_types, :flag, :boolean, default: false
  end
end
