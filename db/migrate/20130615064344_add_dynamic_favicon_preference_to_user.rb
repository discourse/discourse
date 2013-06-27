class AddDynamicFaviconPreferenceToUser < ActiveRecord::Migration
  def change
    add_column :users, :dynamic_favicon, :boolean, default: false, null: false
  end
end
