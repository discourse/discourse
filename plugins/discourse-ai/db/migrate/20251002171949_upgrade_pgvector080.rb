# frozen_string_literal: true

class UpgradePgvector080 < ActiveRecord::Migration[8.0]
  def up
    minimum_target_version = "0.8.0"
    installed_version =
      DB.query_single("SELECT extversion FROM pg_extension WHERE extname = 'vector';").first

    if Gem::Version.new(installed_version) < Gem::Version.new(minimum_target_version)
      DB.exec("ALTER EXTENSION vector UPDATE TO '0.8.0';")

      DB.exec("ALTER ROLE CURRENT_ROLE SET hnsw.iterative_scan = relaxed_order;")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
