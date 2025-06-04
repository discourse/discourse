# frozen_string_literal: true
class RemoveMaxSimilarResultsSiteSetting < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name='max_similar_results'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
