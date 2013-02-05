class AddSearchIndices < ActiveRecord::Migration
  def up
    execute "CREATE INDEX idx_search_user ON users USING GIN(to_tsvector('english', username))"
    execute "CREATE INDEX idx_search_thread ON forum_threads USING GIN(to_tsvector('english', title))"
  end

  def down
    execute "DROP INDEX idx_search_thread"
    execute "DROP INDEX idx_search_user"
  end
end
