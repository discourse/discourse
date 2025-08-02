# frozen_string_literal: true

class AddLowerTitleIndexOnTopics < ActiveRecord::Migration[4.2]
  def up
    execute "CREATE INDEX index_topics_on_lower_title ON topics (LOWER(title))"
  end

  def down
    execute "DROP INDEX index_topics_on_lower_title"
  end
end
