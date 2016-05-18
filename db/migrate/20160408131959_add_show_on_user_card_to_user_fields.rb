class AddShowOnUserCardToUserFields < ActiveRecord::Migration
  def change
    add_column :user_fields, :show_on_user_card, :boolean, default: false, null: false
  end
end
