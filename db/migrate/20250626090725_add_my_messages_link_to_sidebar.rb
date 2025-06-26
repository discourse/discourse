# frozen_string_literal: true
class AddMyMessagesLinkToSidebar < ActiveRecord::Migration[7.2]
  def up
    # Find the community sidebar section
    community_section =
      DB.query_single(
        "SELECT id FROM sidebar_sections WHERE section_type = 0 AND public = true LIMIT 1",
      ).first
    return if !community_section

    # Find the position of "My Posts" link
    my_posts_position = DB.query_single(<<~SQL).first
      SELECT ssl.position
      FROM sidebar_section_links ssl
      JOIN sidebar_urls su ON ssl.linkable_id = su.id
      WHERE ssl.sidebar_section_id = #{community_section}
        AND ssl.linkable_type = 'SidebarUrl'
        AND su.name = 'My Posts'
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

    # First, move all links that come after "My Posts" to temporary high positions
    DB.query <<~SQL
      UPDATE sidebar_section_links
      SET position = position + #{max_position + 100}
      WHERE sidebar_section_id = #{community_section}
        AND linkable_type = 'SidebarUrl'
        AND position > #{my_posts_position}
    SQL

    # Then move them back to their final positions (shifted by 1)
    DB.query <<~SQL
      UPDATE sidebar_section_links
      SET position = position - #{max_position + 100} + 1
      WHERE sidebar_section_id = #{community_section}
        AND linkable_type = 'SidebarUrl'
        AND position > #{max_position + 99}
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
  end

  def down
    # Find the community sidebar section
    community_section =
      DB.query_single(
        "SELECT id FROM sidebar_sections WHERE section_type = 0 AND public = true LIMIT 1",
      ).first
    return if !community_section

    # Find the "My Messages" link and its position
    result = DB.query <<~SQL
      SELECT su.id, ssl.position
      FROM sidebar_urls su
      JOIN sidebar_section_links ssl ON ssl.linkable_id = su.id
      WHERE su.name = 'My Messages' AND su.value = '/my/messages'
        AND ssl.sidebar_section_id = #{community_section}
        AND ssl.linkable_type = 'SidebarUrl'
      LIMIT 1
    SQL

    my_messages_data = result.first
    return if !my_messages_data

    sidebar_url_id = my_messages_data.id
    my_messages_position = my_messages_data.position

    # Remove the "My Messages" link
    DB.query <<~SQL
      DELETE FROM sidebar_section_links
      WHERE linkable_id = #{sidebar_url_id} AND linkable_type = 'SidebarUrl'
    SQL

    DB.query <<~SQL
      DELETE FROM sidebar_urls
      WHERE id = #{sidebar_url_id}
    SQL

    # Shift all links that came after "My Messages" back up by 1 position
    DB.query <<~SQL
      UPDATE sidebar_section_links
      SET position = position - 1
      WHERE sidebar_section_id = #{community_section}
        AND linkable_type = 'SidebarUrl'
        AND position > #{my_messages_position}
    SQL
  end
end
