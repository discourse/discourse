class AddContainsMessagesBackToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :contains_messages, :boolean
  end
end
