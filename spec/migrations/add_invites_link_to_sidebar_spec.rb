# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20241025045928_add_invites_link_to_sidebar.rb")

RSpec.describe AddInvitesLinkToSidebar do
  let(:migrate) { described_class.new.up }

  it "adds Invite link in the primary segment and preserves order and segment of existing links" do
    section = SidebarSection.public_sections.first

    before_migration =
      section
        .sidebar_section_links
        .sort_by(&:position)
        .map do |link|
          [link.position, { name: link.linkable.name, segment: link.linkable.segment }]
        end
        .to_h

    migrate

    after_migration =
      section
        .reload
        .sidebar_section_links
        .sort_by(&:position)
        .map do |link|
          [link.position, { name: link.linkable.name, segment: link.linkable.segment }]
        end
        .to_h

    expect(after_migration.size).to eq(before_migration.size + 1)

    expect(after_migration[0]).to eq(before_migration[0])
    expect(after_migration[0][:name]).to eq("Topics")

    expect(after_migration[1]).to eq(before_migration[1])
    expect(after_migration[1][:name]).to eq("My Posts")

    expect(after_migration[2]).to eq(before_migration[2])
    expect(after_migration[2][:name]).to eq("Review")

    expect(after_migration[3]).to eq(before_migration[3])
    expect(after_migration[3][:name]).to eq("Admin")

    expect(after_migration[4]).to eq({ name: "Invite members", segment: "primary" })

    expect(after_migration[5]).to eq(before_migration[4])
    expect(after_migration[5][:name]).to eq("Users")

    expect(after_migration[6]).to eq(before_migration[5])
    expect(after_migration[6][:name]).to eq("About")

    expect(after_migration[7]).to eq(before_migration[6])
    expect(after_migration[7][:name]).to eq("FAQ")

    expect(after_migration[8]).to eq(before_migration[7])
    expect(after_migration[8][:name]).to eq("Groups")

    expect(after_migration[9]).to eq(before_migration[8])
    expect(after_migration[9][:name]).to eq("Badges")
  end
end
