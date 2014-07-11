class AddFuzzyStrMatchExtension < ActiveRecord::Migration
  def self.up
    execute "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch"
  end

  def self.down
    execute "DROP EXTENSION fuzzystrmatch"
  end
end
