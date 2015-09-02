class AddSuppressFromHomepageToCategory < ActiveRecord::Migration
  def change
    add_column :categories, :suppress_from_homepage, :boolean, default: false
  end
end
