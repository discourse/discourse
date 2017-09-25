require 'ipaddr'

class ChangeIpToInetInViews < ActiveRecord::Migration[4.2]
  def up
    table = :views
    add_column table, :ip_address, :inet

    execute "UPDATE views SET ip_address = inet(
      (ip >> 24 & 255) || '.' ||
      (ip >> 16 & 255) || '.' ||
      (ip >>  8 & 255) || '.' ||
      (ip >>  0 & 255)
    );"

    change_column table, :ip_address, :inet, null: false
    remove_column table, :ip
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
