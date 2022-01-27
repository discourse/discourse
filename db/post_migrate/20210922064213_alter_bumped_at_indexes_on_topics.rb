# frozen_string_literal: true

class AlterBumpedAtIndexesOnTopics < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    execute(<<~SQL)
    CREATE INDEX CONCURRENTLY IF NOT EXISTS index_topics_on_bumped_at_public
    ON topics (bumped_at)
    WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text));
    SQL

    execute(<<~SQL)
    DROP INDEX IF EXISTS index_topics_on_bumped_at;
    SQL

    # The following index is known to have not been properly renamed. Drop it if
    # exists just in case.
    execute(<<~SQL)
    DROP INDEX IF EXISTS index_forum_threads_on_bumped_at;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
