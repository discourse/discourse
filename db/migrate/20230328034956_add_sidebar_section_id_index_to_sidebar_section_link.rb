# frozen_string_literal: true

class AddSidebarSectionIdIndexToSidebarSectionLink < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS idx_sidebar_section_links_on_sidebar_section_id
    SQL

    execute <<~SQL
    CREATE UNIQUE INDEX CONCURRENTLY idx_sidebar_section_links_on_sidebar_section_id
    ON sidebar_section_links (sidebar_section_id, user_id, position)
    SQL

    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS links_user_id_section_id_position
    SQL
  end

  def down
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS idx_sidebar_section_links_on_sidebar_section_id
    SQL

    add_index :sidebar_section_links,
              %i[user_id sidebar_section_id position],
              unique: true,
              name: "links_user_id_section_id_position"
  end
end
