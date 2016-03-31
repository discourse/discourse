class RenameIsSupportToContainsMessages < ActiveRecord::Migration
  def change
    rename_column :categories, :is_support, :contains_messages
  end
end
