# frozen_string_literal: true

class RenameDataExplorerApiKeyScopeResource < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE api_key_scopes
      SET resource = 'data_explorer'
      WHERE resource = 'discourse_data_explorer'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE api_key_scopes
      SET resource = 'discourse_data_explorer'
      WHERE resource = 'data_explorer'
    SQL
  end
end
