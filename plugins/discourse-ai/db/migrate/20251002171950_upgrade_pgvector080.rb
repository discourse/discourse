# frozen_string_literal: true

class UpgradePgvector080 < ActiveRecord::Migration[8.0]
  def up
    # No-op. Migration is failing with "must be owner of extension vector"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
