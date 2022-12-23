# frozen_string_literal: true

class MigrateSidebarSiteSettings < ActiveRecord::Migration[7.0]
  def up
    previous_enable_experimental_sidebar_hamburger = DB.query_single(
      "SELECT value FROM site_settings WHERE name = 'enable_experimental_sidebar_hamburger'"
    )[0]

    previous_enable_sidebar = DB.query_single(
      "SELECT value FROM site_settings WHERE name = 'enable_sidebar'"
    )[0]

    value =
      case [previous_enable_experimental_sidebar_hamburger, previous_enable_sidebar]
      when ['t', 't'], ['t', nil]
        "sidebar"
      when ['t', 'f']
        "header dropdown"
      when ['f', 't'], ['f', 'f'], ['f', nil]
        "legacy"
      when [nil, 't'], [nil, 'f'], [nil, nil]
        nil
      end

    if value
      execute(<<~SQL)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('navigation_menu', 8, '#{value}', now(), now())
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
