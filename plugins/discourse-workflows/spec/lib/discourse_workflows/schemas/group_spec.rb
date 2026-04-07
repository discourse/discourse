# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Schemas::Group do
  fab!(:group) do
    Fabricate(
      :group,
      name: "test_group",
      full_name: "Test Group",
      bio_raw: "A test group",
      visibility_level: Group.visibility_levels[:staff],
      mentionable_level: Group::ALIAS_LEVELS[:members_mods_and_admins],
      messageable_level: Group::ALIAS_LEVELS[:members_mods_and_admins],
    )
  end

  describe ".fields" do
    it "returns the expected field definitions" do
      fields = described_class.fields

      expect(fields).to include(
        id: :integer,
        name: :string,
        full_name: :string,
        user_count: :integer,
        automatic: :boolean,
        visibility_level: :integer,
        mentionable_level: :integer,
        messageable_level: :integer,
        bio_raw: :string,
        created_at: :string,
      )
    end
  end

  describe ".resolve" do
    it "returns resolved group data" do
      result = described_class.resolve(group)

      expect(result[:id]).to eq(group.id)
      expect(result[:name]).to eq("test_group")
      expect(result[:full_name]).to eq("Test Group")
      expect(result[:user_count]).to eq(0)
      expect(result[:automatic]).to be(false)
      expect(result[:visibility_level]).to eq(Group.visibility_levels[:staff])
      expect(result[:mentionable_level]).to eq(Group::ALIAS_LEVELS[:members_mods_and_admins])
      expect(result[:messageable_level]).to eq(Group::ALIAS_LEVELS[:members_mods_and_admins])
      expect(result[:bio_raw]).to eq("A test group")
      expect(result[:created_at]).to eq(group.created_at.iso8601)
    end
  end
end
