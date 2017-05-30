class FixSearchIndex < ActiveRecord::Migration
  def self.up
    Rake::Task['search:reindex'].invoke
  end
end
