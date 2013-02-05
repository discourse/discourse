class AddDescriptionToExpressionTypes < ActiveRecord::Migration
  def change
    add_column :expression_types, :description, :text, null: true
  end
end
