# frozen_string_literal: true
class AddMyMessagesLinkToSidebar < ActiveRecord::Migration[7.2]
  def up
    # Find the community sidebar section
    community_section =
      DB.query_single(
        "SELECT id FROM sidebar_sections WHERE section_type = 0 AND public = true LIMIT 1",
      ).first
    return if !community_section

    # Check if "My Messages" link already exists
    existing_messages_link = DB.query_single(<<~SQL).first
      SELECT ssl.id
      FROM sidebar_section_links ssl
      JOIN sidebar_urls su ON ssl.linkable_id = su.id
      WHERE ssl.sidebar_section_id = #{community_section}
        AND ssl.linkable_type = 'SidebarUrl'
        AND su.value = '/my/messages'
      LIMIT 1
    SQL

    # If the link already exists, we're done
    return if existing_messages_link

    # Clean up any orphaned URLs with `/my/messages` value
    DB.query(<<~SQL)
      DELETE FROM sidebar_urls 
      WHERE value = '/my/messages'
        AND id NOT IN (
          SELECT DISTINCT linkable_id 
          FROM sidebar_section_links 
          WHERE linkable_type = 'SidebarUrl'
        )
    SQL

    # Find the position of "My Posts" link
    my_posts_position = DB.query_single(<<~SQL).first
      SELECT ssl.position
      FROM sidebar_section_links ssl
      JOIN sidebar_urls su ON ssl.linkable_id = su.id
      WHERE ssl.sidebar_section_id = #{community_section}
        AND ssl.linkable_type = 'SidebarUrl'
        AND su.value = '/my/activity'
      LIMIT 1
    SQL

    return if !my_posts_position

    # Get the maximum position to use as a temporary offset
    max_position = DB.query_single(<<~SQL).first || 0
      SELECT COALESCE(MAX(position), -1)
      FROM sidebar_section_links
      WHERE sidebar_section_id = #{community_section}
        AND linkable_type = 'SidebarUrl'
    SQL

    # Use a much higher temporary offset to avoid conflicts
    temp_offset = max_position + 1000

    # First, move all links that come after "My Posts" to temporary high positions
    DB.query <<~SQL
      UPDATE sidebar_section_links
      SET position = position + #{temp_offset}
      WHERE sidebar_section_id = #{community_section}
        AND linkable_type = 'SidebarUrl'
        AND position > #{my_posts_position}
    SQL

    # Insert the "My Messages" sidebar URL
    result = DB.query <<~SQL
      INSERT INTO sidebar_urls(name, value, icon, segment, external, created_at, updated_at)
      VALUES ('My Messages', '/my/messages', 'inbox', 0, false, now(), now())
      RETURNING sidebar_urls.id
    SQL

    sidebar_url_id = result.first&.id
    return if !sidebar_url_id

    # Insert "My Messages" right after "My Posts"
    DB.query <<~SQL
      INSERT INTO sidebar_section_links(user_id, linkable_id, linkable_type, sidebar_section_id, position, created_at, updated_at)
      VALUES (-1, #{sidebar_url_id}, 'SidebarUrl', #{community_section}, #{my_posts_position + 1}, now(), now())
    SQL

    # Finally, move the temporarily displaced links back to their correct positions (shifted by 1)
    DB.query <<~SQL
      UPDATE sidebar_section_links
      SET position = position - #{temp_offset} + 1
      WHERE sidebar_section_id = #{community_section}
        AND linkable_type = 'SidebarUrl'
        AND position > #{temp_offset}
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
