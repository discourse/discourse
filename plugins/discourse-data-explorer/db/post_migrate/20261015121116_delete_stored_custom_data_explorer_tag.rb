# frozen_string_literal: true

# "custom" is now derived from query ownership, so a stored copy is redundant on
# user queries and invalid on bundled ones.
class DeleteStoredCustomDataExplorerTag < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      DELETE FROM data_explorer_query_tags
      WHERE query_tag_id IN (SELECT id FROM data_explorer_tags WHERE name = 'custom')
    SQL

    execute "DELETE FROM data_explorer_tags WHERE name = 'custom'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
