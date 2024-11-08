# frozen_string_literal: true

class DropPathWhitelistFromEmbeddableHosts < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS = { embeddable_hosts: %i[path_whitelist] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    add_column :embeddable_hosts, :path_whitelist, :string
  end
end
