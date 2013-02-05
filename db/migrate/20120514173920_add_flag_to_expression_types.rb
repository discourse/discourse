class AddFlagToExpressionTypes < ActiveRecord::Migration
  def change
    add_column :expression_types, :flag, :boolean, default: false
  end
end
