# frozen_string_literal: true

class FixMigratedHosts < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE embeddable_hosts SET host = regexp_replace(host, '^https?:\/\/', '', 'i')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
