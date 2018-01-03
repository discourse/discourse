class CreateCategoryFeaturedUsers < ActiveRecord::Migration[4.2]
  def change
    create_table :category_featured_users do |t|
      t.references :category
      t.references :user
      t.timestamps null: false
    end

    add_index :category_featured_users, [:category_id, :user_id], unique: true
  end
end
