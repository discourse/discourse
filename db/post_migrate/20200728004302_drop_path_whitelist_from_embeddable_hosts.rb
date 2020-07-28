# frozen_string_literal: true

class DropPathWhitelistFromEmbeddableHosts < ActiveRecord::Migration[6.0]
  def up
    Migration::ColumnDropper.execute_drop(:embeddable_host, :path_whitelist)
  end

  def down
    add_column :embeddable_hosts, :path_whitelist, :string
  end
end
