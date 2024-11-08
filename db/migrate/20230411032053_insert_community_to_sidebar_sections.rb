# frozen_string_literal: true

class InsertCommunityToSidebarSections < ActiveRecord::Migration[7.0]
  COMMUNITY_SECTION_LINKS = [
    { name: "Everything", path: "/latest", icon: "layer-group", segment: 0 },
    { name: "My Posts", path: "/my/activity", icon: "user", segment: 0 },
    { name: "Review", path: "/review", icon: "flag", segment: 0 },
    { name: "Admin", path: "/admin", icon: "wrench", segment: 0 },
    { name: "Users", path: "/u", icon: "users", segment: 1 },
    { name: "About", path: "/about", icon: "info-circle", segment: 1 },
    { name: "FAQ", path: "/faq", icon: "question-circle", segment: 1 },
    { name: "Groups", path: "/g", icon: "user-friends", segment: 1 },
    { name: "Badges", path: "/badges", icon: "certificate", segment: 1 },
  ].freeze
  def up
    result = DB.query <<~SQL
      INSERT INTO sidebar_sections(user_id, title, public, section_type, created_at, updated_at)
      VALUES (-1, 'Community', true, 0, now(), now())
      RETURNING sidebar_sections.id
    SQL

    community_section_id = result.last&.id

    sidebar_urls =
      COMMUNITY_SECTION_LINKS.map do |url_data|
        "('#{url_data[:name]}', '#{url_data[:path]}', '#{url_data[:icon]}', '#{url_data[:segment]}', false, now(), now())"
      end

    result = DB.query <<~SQL
      INSERT INTO sidebar_urls(name, value, icon, segment, external, created_at, updated_at)
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
      WHERE section_type = 0
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
