class AddLowerTitleIndexOnTopics < ActiveRecord::Migration
  def up
    execute "CREATE INDEX index_topics_on_lower_title ON topics (LOWER(title))"
  end

  def down
    execute "DROP INDEX index_topics_on_lower_title"
  end
end
