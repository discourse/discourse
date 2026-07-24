# frozen_string_literal: true

return if SiteSetting.sidebar_seeded

community_section =
  SidebarSection
    .seed(:section_type) do |s|
      s.user_id = Discourse::SYSTEM_USER_ID
      s.title = "Community"
      s.public = true
      s.section_type = SidebarSection.section_types[:community]
    end
    .first

SidebarUrl::COMMUNITY_SECTION_LINKS.each_with_index do |link, position|
  url =
    SidebarUrl
      .seed(:value, :name) do |u|
        u.name = link[:name]
        u.value = link[:path]
        u.icon = link[:icon]
        u.segment = link[:segment]
        u.external = false
      end
      .first

  SidebarSectionLink.seed(:sidebar_section_id, :linkable_type, :linkable_id) do |l|
    l.user_id = Discourse::SYSTEM_USER_ID
    l.linkable_id = url.id
    l.linkable_type = "SidebarUrl"
    l.sidebar_section_id = community_section.id
    l.position = position
  end
end

SiteSetting.sidebar_seeded = true
