class AddCategoryUsers < ActiveRecord::Migration
  def change
    create_table :category_users do |t|
      t.column :category_id, :integer, null: false
      t.column :user_id, :integer, null: false
      t.column :notification_level, :integer, null: false
    end
  end
end
