# frozen_string_literal: true

describe SidebarSectionUpdater do
  fab!(:admin)
  fab!(:sidebar_section) { Fabricate(:sidebar_section, public: true) }
  fab!(:first_url) { Fabricate(:sidebar_url, name: "First", value: "/first") }
  fab!(:second_url) { Fabricate(:sidebar_url, name: "Second", value: "/second") }

  before do
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: first_url, position: 0)
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: second_url, position: 1)
  end

  it "updates the section, persists submitted link order, and publishes public updates" do
    Site.expects(:clear_anon_cache!)

    messages =
      MessageBus.track_publish("/refresh-sidebar-sections") do
        described_class.update!(
          sidebar_section:,
          user: admin,
          section_params: {
            title: "Updated section",
            public: true,
          },
          links_params: [
            { id: second_url.id, icon: "link", name: "Second edited", value: "/second" },
            { id: first_url.id, icon: "link", name: "First edited", value: "/first" },
            { icon: "link", name: "Third", value: "/third" },
          ],
        )
      end

    expect(messages.size).to eq(1)
    expect(sidebar_section.reload.title).to eq("Updated section")
    expect(
      sidebar_section.reload.sidebar_section_links.reload.map { |link| link.linkable.name },
    ).to eq(["Second edited", "First edited", "Third"])
    expect(UserHistory.last.action).to eq(UserHistory.actions[:update_public_sidebar_section])
    expect(UserHistory.last.acting_user_id).to eq(admin.id)
  end
end
