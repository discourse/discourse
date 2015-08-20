class CreateEmbeddableHosts < ActiveRecord::Migration
  def change
    create_table :embeddable_hosts, force: true do |t|
      t.string :host, null: false
      t.integer :category_id, null: false
      t.timestamps
    end

    category_id = 0;
    category_row = execute("SELECT c.id FROM categories AS c
                        INNER JOIN site_settings AS s ON s.value = c.name
                        WHERE s.name = 'embed_category'")

    if category_row.cmd_tuples > 0
      category_id = category_row[0]['id'].to_i
    end

    if category_id == 0
      category_id = execute("SELECT value FROM site_settings WHERE name = 'uncategorized_category_id'")[0]['value'].to_i
    end

    embeddable_hosts = execute("SELECT value FROM site_settings WHERE name = 'embeddable_hosts'")
    if embeddable_hosts && embeddable_hosts.cmd_tuples > 0
      val = embeddable_hosts[0]['value']
      if val.present?
        records = val.split("\n")
        if records.present?
          records.each do |h|
            execute "INSERT INTO embeddable_hosts (host, category_id, created_at, updated_at) VALUES ('#{h}', #{category_id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
          end
        end
      end
    end

    execute "DELETE FROM site_settings WHERE name IN ('embeddable_hosts', 'embed_category')"
  end
end
