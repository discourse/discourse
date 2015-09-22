class AddActionCodeToPost < ActiveRecord::Migration
  def change
    add_column :posts, :action_code, :string, null: true
  end
end
