# frozen_string_literal: true

class DuplicateAllowedPathsFromPathWhitelist < ActiveRecord::Migration[6.0]
  def up
    unless column_exists?(:embeddable_hosts, :allowed_paths)
      add_column :embeddable_hosts, :allowed_paths, :string
    end

    if column_exists?(:embeddable_hosts, :path_whitelist)
      Migration::ColumnDropper.mark_readonly("embeddable_hosts", "path_whitelist")

      DB.exec <<~SQL if column_exists?(:embeddable_hosts, :allowed_paths)
          UPDATE embeddable_hosts
          SET allowed_paths = path_whitelist
        SQL
    end
  end

  def down
    remove_column :embeddable_hosts, :allowed_paths
  end
end
