# frozen_string_literal: true

class AddPathWhitelistToEmbeddableHosts < ActiveRecord::Migration[4.2]
  def change
    add_column :embeddable_hosts, :path_whitelist, :string
  end
end
