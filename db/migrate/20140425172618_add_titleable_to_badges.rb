class AddTitleableToBadges < ActiveRecord::Migration[4.2]
  def change
    add_column :badges, :allow_title, :boolean, null: false, default: false
  end
end
