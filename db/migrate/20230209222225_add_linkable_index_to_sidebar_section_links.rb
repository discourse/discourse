# frozen_string_literal: true

class AddLinkableIndexToSidebarSectionLinks < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS index_sidebar_section_links_on_linkable_type_and_linkable_id
    SQL

    execute <<~SQL
    CREATE INDEX CONCURRENTLY index_sidebar_section_links_on_linkable_type_and_linkable_id
    ON sidebar_section_links (linkable_type,linkable_id)
    SQL
  end

  def down
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS index_sidebar_section_links_on_linkable_type_and_linkable_id
    SQL
  end
end
