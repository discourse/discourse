# frozen_string_literal: true

class RenamePathWhitelistToPathAllowlist < ActiveRecord::Migration[6.0]
  def change
    rename_column :embeddable_hosts, :path_whitelist, :path_allowlist
  end
end
