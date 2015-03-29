class AddIconToBadges < ActiveRecord::Migration
  def change
    add_column :badges, :icon, :string, default: "fa-certificate"
  end
end
