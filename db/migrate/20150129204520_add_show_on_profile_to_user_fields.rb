class AddShowOnProfileToUserFields < ActiveRecord::Migration[4.2]
  def change
    add_column :user_fields, :show_on_profile, :boolean, default: false, null: false
  end
end
