require 'ipaddr'

class ChangeIpToInetInTopicLinkClicks < ActiveRecord::Migration[4.2]
  def up
    add_column :topic_link_clicks, :ip_address, :inet

    execute "UPDATE topic_link_clicks SET ip_address = inet(
      (ip >> 24 & 255) || '.' ||
      (ip >> 16 & 255) || '.' ||
      (ip >>  8 & 255) || '.' ||
      (ip >>  0 & 255)
    );"

    change_column :topic_link_clicks, :ip_address, :inet, null: false
    remove_column :topic_link_clicks, :ip
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
