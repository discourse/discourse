# frozen_string_literal: true

class KeepCategoriesAndLatestTopicsPageStyleForExistingSites < ActiveRecord::Migration[8.1]
  def up
    return if !Migration::Helpers.existing_site?

    # data_type 7 is enum; the previous default is persisted so existing sites keep their layout.
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES('desktop_category_page_style', 7, 'categories_and_latest_topics', NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
