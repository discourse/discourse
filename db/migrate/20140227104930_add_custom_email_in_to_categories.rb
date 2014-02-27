class AddCustomEmailInToCategories < ActiveRecord::Migration
  def up
  	add_column :categories, :email_in, :string, null: true
  	add_index :categories, :email_in, unique: true
  end
  def down
  	remove_column :categories, :email_in
  	remove_index :categories, :email_in
  end
end
