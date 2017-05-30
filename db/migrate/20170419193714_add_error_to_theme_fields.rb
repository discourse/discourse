class AddErrorToThemeFields < ActiveRecord::Migration
  def change
    add_column :theme_fields, :error, :string
  end
end
