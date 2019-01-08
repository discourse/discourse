class AddFontSizeIdToUserOptions < ActiveRecord::Migration[5.2]
  def change
    add_column :user_options, :font_size_id, :integer, null: false, default: 0
  end
end
