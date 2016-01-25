class RemoveContainsMessageOnCategory < ActiveRecord::Migration
  def change
    remove_column :categories, :contains_messages
  end
end
