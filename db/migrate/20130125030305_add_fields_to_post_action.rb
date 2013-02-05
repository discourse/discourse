class AddFieldsToPostAction < ActiveRecord::Migration
  def change
    add_column :post_actions, :deleted_by, :integer
    add_column :post_actions, :message, :text
  end
end
