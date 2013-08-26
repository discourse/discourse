class AddIpAddressToScreeningTables < ActiveRecord::Migration
  def change
    add_column :screened_emails, :ip_address, :inet
    add_column :screened_urls,   :ip_address, :inet
  end
end
