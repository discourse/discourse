# frozen_string_literal: true

RSpec.describe SidebarSection do
  fab!(:user)
  fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }
  let(:community_section) do
    SidebarSection.find_by(section_type: SidebarSection.section_types[:community])
  end

  it "uses system user for public sections" do
    expect(sidebar_section.user_id).to eq(user.id)
    sidebar_section.update!(public: true)
    expect(sidebar_section.user_id).to eq(Discourse.system_user.id)
  end

  it "resets Community section to the default state" do
    community_section.update!(title: "test")
    community_section.sidebar_section_links.first.linkable.update!(name: "everything edited")
    community_section.sidebar_section_links.last.destroy!
    community_section.reset_community!

    expect(community_section.reload.title).to eq("Community")

    expect(community_section.sidebar_section_links.all.map { |link| link.linkable.name }).to eq(
      [
        "Topics",
        "My Drafts",
        "Review",
        "Admin",
        "Invite",
        "Users",
        "About",
        "FAQ",
        "Groups",
        "Badges",
      ],
    )
  end
end
