# frozen_string_literal: true

class DropVersionedLeaderboardMaterializedViews < ActiveRecord::Migration[7.2]
  def up
    versioned_mviews_query = <<~SQL
      SELECT cls.relname
      FROM pg_class cls
      INNER JOIN pg_namespace ns ON ns.oid = cls.relnamespace
      WHERE cls.relname ~ 'gamification_leaderboard_cache_[0-9]+_[a-zA-Z_]+_[1-9]$'
        AND cls.relkind = 'm'
        AND ns.nspname = 'public'
    SQL

    mviews = DB.query_single(versioned_mviews_query)

    return if mviews.empty?

    execute <<~SQL
      DROP MATERIALIZED VIEW IF EXISTS #{mviews.join(", ")} CASCADE
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
