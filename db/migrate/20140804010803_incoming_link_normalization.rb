class IncomingLinkNormalization < ActiveRecord::Migration
  def up
    remove_column :incoming_links, :post_number
    remove_column :incoming_links, :domain
    add_column :incoming_links, :incoming_referer_id, :integer

    create_table :incoming_referers do |t|
      t.string :url, limit: 1000, null: false
      t.string :domain, limit: 100, null: false
      t.string :path, limit: 1000, null: false
      t.integer :port, null: false
      t.boolean :https, null: false
      t.integer :incoming_domain_id
    end

    # start the shuffle
    #
    execute "INSERT INTO incoming_referers(url, https, domain, port, path)
             SELECT referer,
                    CASE WHEN a[1] = 's' THEN true ELSE false END,
                    a[2] as domain,
                    CASE WHEN a[1] = 's' THEN
                      COALESCE(a[4]::integer, 443)::integer
                    ELSE
                      COALESCE(a[4]::integer, 80)::integer
                    END,
                    COALESCE(a[5], '') path
             FROM
            (
              SELECT referer, regexp_matches(referer, 'http(s)?://([^/:]+)(:(\d+))?(.*)') a
              FROM
              (
               SELECT DISTINCT referer
               FROM incoming_links WHERE referer ~ '^https?://.+'
              ) Z
            ) X
          WHERE a[2] IS NOT NULL"


    execute "UPDATE incoming_links l
    SET incoming_referer_id = r.id
    FROM incoming_referers r
    WHERE r.url = l.referer"

    create_table :incoming_domains do |t|
      t.string :name, limit: 100, null: false
      t.boolean :https, null: false, default: false
      t.integer :port, null: false
    end

    # shuffle part 2
    #
    execute "INSERT INTO incoming_domains(name, port, https)
    SELECT DISTINCT domain, port, https
    FROM incoming_referers"

    execute "UPDATE incoming_referers l
    SET incoming_domain_id = d.id
    FROM incoming_domains d
    WHERE d.name = l.domain AND d.https = l.https AND d.port = l.port"


    remove_column :incoming_referers, :domain
    remove_column :incoming_referers, :port
    remove_column :incoming_referers, :https

    change_column :incoming_referers, :incoming_domain_id, :integer, null: false

    add_index :incoming_referers, [:path, :incoming_domain_id], unique: true
    add_index :incoming_domains, [:name, :https, :port], unique: true

    remove_column :incoming_links, :referer
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
