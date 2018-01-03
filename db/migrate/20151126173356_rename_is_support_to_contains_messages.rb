class RenameIsSupportToContainsMessages < ActiveRecord::Migration[4.2]
  def change
    rename_column :categories, :is_support, :contains_messages
  end
end
