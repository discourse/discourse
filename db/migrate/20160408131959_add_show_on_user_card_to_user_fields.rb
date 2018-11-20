class AddShowOnUserCardToUserFields < ActiveRecord::Migration[4.2]
  def change
    add_column :user_fields, :show_on_user_card, :boolean, default: false, null: false
  end
end
