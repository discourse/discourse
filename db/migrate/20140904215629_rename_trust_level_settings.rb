# frozen_string_literal: true

class RenameTrustLevelSettings < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE site_settings
             SET name = regexp_replace(name, '^basic_', 'tl1_')"

    execute "UPDATE site_settings
             SET name = regexp_replace(name, '^regular_', 'tl2_')"

    execute "UPDATE site_settings
             SET name = regexp_replace(name, '^leader_', 'tl3_')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
