class AddTitleableToBadges < ActiveRecord::Migration
  def change
    add_column :badges, :allow_title, :boolean, null: false, default: false
  end
end
