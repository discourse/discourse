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
        "My posts",
        "My messages",
        "Review",
        "Admin",
        "Invite",
        "Users",
        "About",
        "FAQ",
        "Groups",
        "Badges",
        "Filter",
      ],
    )
  end

  describe "#apply_links_order!" do
    fab!(:first_url) { Fabricate(:sidebar_url, name: "First", value: "/first") }
    fab!(:second_url) { Fabricate(:sidebar_url, name: "Second", value: "/second") }
    fab!(:third_url) { Fabricate(:sidebar_url, name: "Third", value: "/third") }
    fab!(:first_link) { Fabricate(:sidebar_section_link, sidebar_section:, linkable: first_url) }
    fab!(:second_link) { Fabricate(:sidebar_section_link, sidebar_section:, linkable: second_url) }
    fab!(:third_link) { Fabricate(:sidebar_section_link, sidebar_section:, linkable: third_url) }

    it "orders the links to match the requested order" do
      sidebar_section.apply_links_order!([third_url.id, first_url.id, second_url.id])

      expect(sidebar_section.sidebar_urls.reload.map(&:id)).to eq(
        [third_url.id, first_url.id, second_url.id],
      )
    end

    it "sorts links missing from the requested order last" do
      sidebar_section.apply_links_order!([third_url.id, first_url.id])

      expect(sidebar_section.sidebar_urls.reload.map(&:id)).to eq(
        [third_url.id, first_url.id, second_url.id],
      )
    end

    it "reassigns positions already occupied by other links" do
      sidebar_section.apply_links_order!([third_url.id, second_url.id, first_url.id])

      positions = sidebar_section.sidebar_section_links.reload.map(&:position)
      expect(positions.uniq.size).to eq(3)
      expect(sidebar_section.sidebar_urls.reload.map(&:id)).to eq(
        [third_url.id, second_url.id, first_url.id],
      )
    end

    it "is a no-op for a section without links" do
      empty_section = Fabricate(:sidebar_section, title: "Empty", user: user)

      expect { empty_section.apply_links_order!([first_url.id]) }.not_to change {
        SidebarSectionLink.pluck(:id, :position).sort
      }
    end
  end
end
