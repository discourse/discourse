class AddContainsMessagesBackToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :contains_messages, :boolean
  end
end
