class AddIpAddressToScreeningTables < ActiveRecord::Migration[4.2]
  def change
    add_column :screened_emails, :ip_address, :inet
    add_column :screened_urls,   :ip_address, :inet
  end
end
