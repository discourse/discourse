# frozen_string_literal: true

class InsertCommunityToSidebarSections < ActiveRecord::Migration[7.0]
  COMMUNITY_SECTION_LINKS = [
    {
      name: I18n.t("sidebar.sections.community.links.everything.content", default: "Everything"),
      path: "/latest",
      icon: "layer-group",
      segment: SidebarUrl.segments["primary"],
    },
    {
      name: I18n.t("sidebar.sections.community.links.my_posts.content", default: "My Posts"),
      path: "/my/activity",
      icon: "user",
      segment: SidebarUrl.segments["primary"],
    },
    {
      name: I18n.t("sidebar.sections.community.links.review.content", default: "Review"),
      path: "/review",
      icon: "flag",
      segment: SidebarUrl.segments["primary"],
    },
    {
      name: I18n.t("sidebar.sections.community.links.admin.content", default: "Admin"),
      path: "/admin",
      icon: "wrench",
      segment: SidebarUrl.segments["primary"],
    },
    {
      name: I18n.t("sidebar.sections.community.links.users.content", default: "Users"),
      path: "/u",
      icon: "users",
      segment: SidebarUrl.segments["secondary"],
    },
    {
      name: I18n.t("sidebar.sections.community.links.about.content", default: "About"),
      path: "/about",
      icon: "info-circle",
      segment: SidebarUrl.segments["secondary"],
    },
    {
      name: I18n.t("sidebar.sections.community.links.faq.content", default: "FAQ"),
      path: "/faq",
      icon: "question-circle",
      segment: SidebarUrl.segments["secondary"],
    },
    {
      name: I18n.t("sidebar.sections.community.links.groups.content", default: "Groups"),
      path: "/g",
      icon: "user-friends",
      segment: SidebarUrl.segments["secondary"],
    },
    {
      name: I18n.t("sidebar.sections.community.links.badges.content", default: "Badges"),
      path: "/badges",
      icon: "certificate",
      segment: SidebarUrl.segments["secondary"],
    },
  ]
  def up
    result = DB.query <<~SQL
      INSERT INTO sidebar_sections(user_id, title, public, section_type, created_at, updated_at)
      VALUES (-1, 'Community', true, #{SidebarSection.section_types["community"]}, now(), now())
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
      WHERE section_type = #{SidebarSection.section_types["community"]}
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
