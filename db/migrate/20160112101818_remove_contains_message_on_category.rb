class RemoveContainsMessageOnCategory < ActiveRecord::Migration[4.2]
  def change
    remove_column :categories, :contains_messages
  end
end
