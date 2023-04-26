# frozen_string_literal: true

class InsertCommunityToSidebarSections < ActiveRecord::Migration[7.0]
  def up
    result = DB.query <<~SQL
    INSERT INTO sidebar_sections(id, user_id, title, public, system_section, created_at, updated_at)
      VALUES (-1, -1, 'Community', true, 'community', now(), now())
      RETURNING sidebar_sections.id
    SQL

    community_section_id = result.last&.id

    sidebar_urls =
      SidebarUrl::COMMUNITY_SECTION_LINKS.map do |url_data|
        "(#{url_data[:id]}, '#{url_data[:name]}', '#{url_data[:path]}', '#{url_data[:icon]}', '#{url_data[:segment]}', false, now(), now())"
      end
    puts sidebar_urls.inspect

    result = DB.query <<~SQL
      INSERT INTO sidebar_urls(id, name, value, icon, segment, external, created_at, updated_at)
      VALUES #{sidebar_urls.join(",")}
      RETURNING sidebar_urls.id
    SQL

    sidebar_section_links =
      result.map.with_index do |url, index|
        "(-1, #{url.id}, 'SidebarUrl', #{community_section_id}, #{index},  now(), now())"
      end

    result = DB.query <<~SQL
      INSERT INTO sidebar_section_links(user_id, linkable_id, linkable_type, sidebar_section_id, position, created_at, updated_at)
      VALUES #{sidebar_section_links.join(",")}
    SQL
  end

  def down
    result = DB.query <<~SQL
      DELETE FROM sidebar_sections
      WHERE id = -1
      RETURNING sidebar_sections.id
    SQL
    community_section_id = result.last&.id

    return true if !community_section_id

    result = DB.query <<~SQL
      DELETE FROM sidebar_section_links
      WHERE sidebar_section_id = #{community_section_id}
        RETURNING sidebar_section_links.linkable_id
    SQL
    sidebar_url_ids = result.map(&:linkable_id)

    DB.query <<~SQL
      DELETE FROM sidebar_urls
      WHERE id IN (#{sidebar_url_ids.join(",")})
    SQL
  end
end
