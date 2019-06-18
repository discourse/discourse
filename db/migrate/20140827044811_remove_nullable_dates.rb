# frozen_string_literal: true

class RemoveNullableDates < ActiveRecord::Migration[4.2]
  def up

    # must drop so we can muck with the column
    execute "DROP VIEW badge_posts"

    # Rails 3 used to have nullable created_at and updated_at dates
    #  this is no longer the case in Rails 4, some old installs have
    #  this relic
    #  Fix it
    sql = "select table_name, column_name from information_schema.columns
           WHERE  column_name IN ('created_at','updated_at') AND
                  table_schema = 'public' AND
                  is_nullable = 'YES' AND
                  is_updatable = 'YES' AND
                  data_type = 'timestamp without time zone'"

    execute(sql).each do |row|
      table = row["table_name"]
      column = row["column_name"]

      execute "UPDATE \"#{table}\" SET #{column} = CURRENT_TIMESTAMP WHERE #{column} IS NULL"
      change_column table.to_sym, column.to_sym, :datetime, null: false
    end

    execute "CREATE VIEW badge_posts AS
    SELECT p.*
    FROM posts p
    JOIN topics t ON t.id = p.topic_id
    JOIN categories c ON c.id = t.category_id
    WHERE c.allow_badges AND
          p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          NOT c.read_restricted AND
          t.visible"

  end

  def down
    # no need to revert
  end
end
