class AddAutoCloseBasedOnLastPostToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :auto_close_based_on_last_post, :boolean, default: false
  end
end
