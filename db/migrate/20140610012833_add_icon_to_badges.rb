class AddIconToBadges < ActiveRecord::Migration[4.2]
  def change
    add_column :badges, :icon, :string, default: "fa-certificate"
  end
end
