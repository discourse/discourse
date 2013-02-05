class AddIconToExpressionTypes < ActiveRecord::Migration
  def change
    add_column :expression_types, :icon, :string, limit: 20

    execute "UPDATE expression_types SET icon = 'heart' WHERE expression_index = 1"
  end
end
