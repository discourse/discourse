class AddThemeKeyToUserOptions < ActiveRecord::Migration[4.2]
  def change
    add_column :user_options, :theme_key, :string
  end
end
