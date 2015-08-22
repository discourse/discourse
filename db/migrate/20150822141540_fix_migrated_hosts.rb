class FixMigratedHosts < ActiveRecord::Migration
  def up
    execute "UPDATE embeddable_hosts SET host = regexp_replace(host, '^https?:\/\/', '', 'i')"
  end
end
