# frozen_string_literal: true

class RenamePathWhitelistToAllowedPaths < ActiveRecord::Migration[6.0]
  def change
    rename_column :embeddable_hosts, :path_whitelist, :allowed_paths
  end
end
