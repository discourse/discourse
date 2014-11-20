class AddAllowedIpsToApiKeys < ActiveRecord::Migration
  def change
    change_table :api_keys do |t|
      t.inet :allowed_ips, array: true
    end
  end
end
