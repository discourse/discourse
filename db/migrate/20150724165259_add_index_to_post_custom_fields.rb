class AddIndexToPostCustomFields < ActiveRecord::Migration
  def change
    add_index :post_custom_fields, [:name, :value]
  end
end
