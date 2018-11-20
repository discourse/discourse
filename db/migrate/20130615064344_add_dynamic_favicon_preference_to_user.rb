class AddDynamicFaviconPreferenceToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :dynamic_favicon, :boolean, default: false, null: false
  end
end
