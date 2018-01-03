class AddAllowedIpsToApiKeys < ActiveRecord::Migration[4.2]
  def change
    change_table :api_keys do |t|
      t.inet :allowed_ips, array: true
    end
  end
end
