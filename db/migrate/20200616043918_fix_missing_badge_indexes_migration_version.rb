# frozen_string_literal: true

class FixMissingBadgeIndexesMigrationVersion < ActiveRecord::Migration[6.0]
  def change
    DB.exec("UPDATE schema_versions SET version = '20200611104600' WHERE version = '20201006172700'")
  end
end
