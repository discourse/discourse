class AddAutoRevokeToBadges < ActiveRecord::Migration[4.2]
  def change
    add_column :badges, :auto_revoke, :boolean, default: true, null: false
  end
end
