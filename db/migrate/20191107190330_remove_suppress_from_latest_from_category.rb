# frozen_string_literal: true

class RemoveSuppressFromLatestFromCategory < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS = { categories: %i[suppress_from_latest] }

  def up
    ids = DB.query_single("SELECT id::text FROM categories WHERE suppress_from_latest = TRUE")

    if ids.present?
      muted_ids =
        DB.query_single(
          "SELECT value from site_settings WHERE name = 'default_categories_muted'",
        ).first
      ids += muted_ids.split("|") if muted_ids.present?
      ids.uniq!

      # We shouldn't encourage to have more than 10 categories in `default_categories_muted` site setting.
      if ids.count <= 10
        # CategoryUser.notification_levels[:muted] is 0, avoid reaching to object model
        DB.exec(<<~SQL, muted: 0)
          INSERT INTO category_users (category_id, user_id, notification_level)
            SELECT c.id category_id, u.id user_id, :muted
            FROM users u
              CROSS JOIN categories c
              LEFT JOIN category_users cu
                ON u.id = cu.user_id
                  AND c.id = cu.category_id
            WHERE c.suppress_from_latest = TRUE
              AND cu.notification_level IS NULL
          ON CONFLICT DO NOTHING
        SQL

        DB.exec(<<~SQL, value: ids.join("|"))
          UPDATE site_settings
          SET value = :value
          WHERE name = 'default_categories_muted'
        SQL
      end
    end

    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
