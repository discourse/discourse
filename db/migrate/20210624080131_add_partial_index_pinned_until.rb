# frozen_string_literal: true

class AddPartialIndexPinnedUntil < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  # Dropping to raw SQL here due to an ActiveRecord bug which prevents
  # using `algorithm: :concurrently` and `if_not_exists: true`
  # https://github.com/rails/rails/pull/41490

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS "index_topics_on_pinned_until"
      ON "topics" ("pinned_until")
      WHERE pinned_until IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS "index_topics_on_pinned_until"
    SQL
  end
end
