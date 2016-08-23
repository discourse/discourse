class AddPathWhitelistToEmbeddableHosts < ActiveRecord::Migration
  def change
    add_column :embeddable_hosts, :path_whitelist, :string
  end
end
