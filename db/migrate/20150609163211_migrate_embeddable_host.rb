class MigrateEmbeddableHost < ActiveRecord::Migration[4.2]
  def change
    execute "UPDATE site_settings SET name = 'embeddable_hosts', data_type = 9 WHERE name = 'embeddable_host'"
  end
end
