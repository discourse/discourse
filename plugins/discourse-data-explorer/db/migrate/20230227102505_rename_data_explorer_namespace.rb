# frozen_string_literal: true

class RenameDataExplorerNamespace < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE api_key_scopes
      SET resource = 'discourse_data_explorer'
      WHERE resource = 'data_explorer'
    SQL

    execute <<~SQL
      UPDATE bookmarks
      SET bookmarkable_type = 'DiscourseDataExplorer::QueryGroup'
      WHERE bookmarkable_type = 'DataExplorer::QueryGroup'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE api_key_scopes
      SET resource = 'data_explorer'
      WHERE resource = 'discourse_data_explorer'
    SQL

    execute <<~SQL
      UPDATE bookmarks
      SET bookmarkable_type = 'DiscourseDataExplorer::QueryGroup'
      WHERE bookmarkable_type = 'DataExplorer::QueryGroup'
    SQL
  end
end
