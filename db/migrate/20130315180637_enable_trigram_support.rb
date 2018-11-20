class EnableTrigramSupport < ActiveRecord::Migration[4.2]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
  end

  def down
    execute "DROP EXTENSION pg_trgm"
  end
end
