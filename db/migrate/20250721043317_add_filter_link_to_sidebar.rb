# frozen_string_literal: true
class AddFilterLinkToSidebar < ActiveRecord::Migration[7.0]
  def up
    # Find the community section
    community_section_id = execute(<<~SQL).first&.fetch("id")
      SELECT id FROM sidebar_sections WHERE section_type = 0 LIMIT 1
    SQL
    return if !community_section_id

    # Find or insert the filter url
    filter_url_id = execute(<<~SQL).first&.fetch("id")
      SELECT id FROM sidebar_urls WHERE value = '/filter' AND name = 'Filter' AND NOT external LIMIT 1
    SQL

    filter_url_id ||= execute(<<~SQL).first["id"]
        INSERT INTO sidebar_urls (name, value, icon, segment, external, created_at, updated_at)
        VALUES ('Filter', '/filter', 'filter', 1, false, NOW(), NOW())
        RETURNING id
      SQL

    exists = execute(<<~SQL).first
      SELECT 1 FROM sidebar_section_links
        WHERE sidebar_section_id = #{community_section_id.to_i}
        AND linkable_id = #{filter_url_id.to_i}
        AND linkable_type = 'SidebarUrl'
      LIMIT 1
    SQL

    if !exists
      position = execute(<<~SQL).first&.fetch("pos") || 0
        SELECT MAX(position) pos FROM sidebar_section_links
        WHERE sidebar_section_id = #{community_section_id}
        AND user_id = -1
      SQL
      position += 1
      execute(<<~SQL)
        INSERT INTO sidebar_section_links
          (user_id, linkable_id, linkable_type, sidebar_section_id, position, created_at, updated_at)
        VALUES (-1, #{filter_url_id}, 'SidebarUrl', #{community_section_id}, #{position.to_i}, NOW(), NOW())
      SQL
    end
  end

  def down
    filter_url_id =
      execute("SELECT id FROM sidebar_urls WHERE value = '/filter' LIMIT 1").first&.fetch("id")
    if filter_url_id
      execute(
        "DELETE FROM sidebar_section_links WHERE linkable_id = #{filter_url_id} AND linkable_type = 'SidebarUrl'",
      )
      execute("DELETE FROM sidebar_urls WHERE id = #{filter_url_id}")
    end
  end
end
