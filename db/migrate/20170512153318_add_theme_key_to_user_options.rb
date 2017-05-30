class AddThemeKeyToUserOptions < ActiveRecord::Migration
  def change
    add_column :user_options, :theme_key, :string
  end
end
