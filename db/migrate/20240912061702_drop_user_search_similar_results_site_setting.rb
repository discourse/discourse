# frozen_string_literal: true
class DropUserSearchSimilarResultsSiteSetting < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'user_search_similar_results';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
