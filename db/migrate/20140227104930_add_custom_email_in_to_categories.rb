class AddCustomEmailInToCategories < ActiveRecord::Migration[4.2]
  def up
    add_column :categories, :email_in, :string, null: true
    add_column :categories, :email_in_allow_strangers, :boolean, default: false
    add_index :categories, :email_in, unique: true
  end
  def down
    remove_column :categories, :email_in
    remove_column :categories, :email_in_allow_strangers
    remove_index :categories, :email_in
  end
end
