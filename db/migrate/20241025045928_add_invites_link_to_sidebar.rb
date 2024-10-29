# frozen_string_literal: true

class AddInvitesLinkToSidebar < ActiveRecord::Migration[7.1]
  def up
    community_section_id = DB.query_single(<<~SQL).first
      SELECT id
      FROM sidebar_sections
      WHERE section_type = 0
    SQL

    return if !community_section_id

    max_position = DB.query_single(<<~SQL, section_id: community_section_id).first
      SELECT MAX(ssl.position)
        FROM sidebar_urls su
             JOIN sidebar_section_links ssl ON su.id = ssl.linkable_id
       WHERE ssl.linkable_type = 'SidebarUrl'
         AND ssl.sidebar_section_id = :section_id
         AND su.segment = 0
    SQL

    updated_rows = DB.query_hash(<<~SQL, position: max_position, section_id: community_section_id)
      DELETE FROM sidebar_section_links
       WHERE position > :position
         AND sidebar_section_id = :section_id
         AND linkable_type = 'SidebarUrl'
      RETURNING user_id, linkable_id, linkable_type, sidebar_section_id, position + 1 AS position, created_at, updated_at
    SQL
    updated_rows.each { |row| DB.exec(<<~SQL, **row.symbolize_keys) }
        INSERT INTO sidebar_section_links
        (user_id, linkable_id, linkable_type, sidebar_section_id, position, created_at, updated_at)
        VALUES
        (:user_id, :linkable_id, :linkable_type, :sidebar_section_id, :position, :created_at, :updated_at)
      SQL

    link_id = DB.query_single(<<~SQL).first
      INSERT INTO sidebar_urls
      (name, value, icon, external, segment, created_at, updated_at)
      VALUES
      ('Invite', '/new-invite', 'paper-plane', false, 0, now(), now())
      RETURNING sidebar_urls.id
    SQL

    DB.exec(<<~SQL, link_id:, section_id: community_section_id, position: max_position + 1)
      INSERT INTO sidebar_section_links
      (user_id, linkable_id, linkable_type, sidebar_section_id, position, created_at, updated_at)
      VALUES
      (-1, :link_id, 'SidebarUrl', :section_id, :position, now(), now())
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
