# frozen_string_literal: true

class DropPathWhitelistFromEmbeddableHosts < ActiveRecord::Migration[6.0]
  def up
    if column_exists?(:embeddable_hosts, :path_whitelist)
      remove_column :embeddable_hosts, :path_whitelist
    end
  end

  def down
    add_column :embeddable_hosts, :path_whitelist, :string
  end
end
