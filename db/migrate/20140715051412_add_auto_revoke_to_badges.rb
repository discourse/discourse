class AddAutoRevokeToBadges < ActiveRecord::Migration
  def change
    add_column :badges, :auto_revoke, :boolean, default: true, null: false
  end
end
