# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/group_mapping"

RSpec.describe BulkImport::DiscourseMerge::GroupMapping do
  let(:inventory) do
    {
      "source" => {
        "groups" => [
          { "id" => "100", "name" => "customers", "automatic" => "f" },
          { "id" => "101", "name" => "partners", "automatic" => "f" },
          { "id" => "13", "name" => "trust_level_3", "automatic" => "t" },
        ],
      },
      "destination" => {
        "groups" => [
          { "id" => "200", "name" => "customers", "automatic" => "f" },
          { "id" => "1", "name" => "admins", "automatic" => "t" },
        ],
      },
    }
  end

  it "keeps colliding groups separate without identity evidence and ignores automatic groups" do
    groups = described_class.build(inventory, described_class.defaults(inventory))
    expect(groups.map { |group| [group["source_group_id"], group["name"], group["action"]] }).to eq(
      [[100, "customers_1", "copy"], [101, "partners", "copy"]],
    )
  end

  it "reuses explicitly chosen custom groups while preserving stable routing after rows move" do
    rows = described_class.defaults(inventory)
    rows.each { |row| row.merge!("action" => "reuse", "destination_group_id" => "200") }
    groups = described_class.build(inventory, rows)
    expect(groups).to eq(described_class.build(inventory, rows.reverse))
    expect(groups.map { |group| group["destination_group_id"] }).to eq([200, 200])
  end

  it "rejects automatic group targets" do
    rows = described_class.defaults(inventory)
    rows.first.merge!("action" => "reuse", "destination_group_id" => "1")
    expect { described_class.build(inventory, rows) }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /existing custom destination group/,
    )
  end

  it "rejects missing, duplicate and unknown source mappings" do
    rows = described_class.defaults(inventory)
    [
      rows.drop(1),
      rows + [rows.first],
      rows + [{ "source_group_id" => "999", "action" => "copy" }],
    ].each do |invalid|
      expect { described_class.build(inventory, invalid) }.to raise_error(
        BulkImport::DiscourseMerge::Error,
      )
    end
  end

  it "excludes a source group without choosing or deleting a destination group" do
    rows = described_class.defaults(inventory)
    rows.first["action"] = "exclude"
    group = described_class.build(inventory, rows).first
    expect(group).to include(
      "action" => "exclude",
      "name" => "customers",
      "destination_group_id" => nil,
    )
    expect(described_class.excluded([group])).to eq(Set[100])
  end

  it "rejects destination or rename values on exclusions" do
    rows = described_class.defaults(inventory)
    rows.first.merge!("action" => "exclude", "destination_group_id" => "200")
    expect { described_class.build(inventory, rows) }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /exclusion cannot specify/,
    )
  end

  it "preserves references to excluded groups as historical metadata" do
    value = {
      "nested" => [{ "group_id" => [100, 101], "text" => "Original history" }],
      "group_id" => 101,
    }
    expect(described_class.metadata_references?(value, Set[100])).to eq(true)
    expect(described_class.preserve_metadata(value, Set[100], "incoming")).to eq(
      {
        "nested" => [{ "incoming_original_group_id" => [100, 101], "text" => "Original history" }],
        "group_id" => 101,
      },
    )
  end

  def matching_members
    inventory["source"]["group_memberships"] = [
      { "group_id" => "100", "user_id" => "1" },
      { "group_id" => "100", "user_id" => "2" },
    ]
    inventory["source"]["group_user_matches"] = [
      { "source_user_id" => 1, "destination_user_id" => 9 },
      { "source_user_id" => 2, "destination_user_id" => 10 },
    ]
    inventory["destination"]["group_memberships"] = [
      { "group_id" => "200", "user_id" => "9" },
      { "group_id" => "200", "user_id" => "10" },
    ]
  end

  it "automatically reuses a same-named group with exactly the same resulting accounts" do
    matching_members
    inventory["destination"]["groups"][0]["name"] = "Customers"
    group = described_class.build(inventory, described_class.defaults(inventory)).first
    expect(group).to include(
      "action" => "reuse",
      "destination_group_id" => 200,
      "name" => "Customers",
    )
    expect(group.fetch("automatic_match")).to include("exact member list")
  end

  it "keeps groups separate if the destination has extra members or missing members" do
    matching_members
    inventory["destination"]["group_memberships"] << { "group_id" => "200", "user_id" => "11" }
    group = described_class.build(inventory, described_class.defaults(inventory)).first
    expect(group).to include(
      "action" => "copy",
      "destination_group_id" => nil,
      "name" => "customers_1",
    )
    expect(group.fetch("automatic_match")).to include("Member lists differ")
    inventory["destination"]["group_memberships"] = []
    expect(
      described_class.build(inventory, described_class.defaults(inventory)).first.fetch("action"),
    ).to eq("copy")
  end

  it "keeps groups separate if any incoming member is a new or unmatched account" do
    matching_members
    inventory["source"]["group_user_matches"].pop
    group = described_class.build(inventory, described_class.defaults(inventory)).first
    expect(group.fetch("action")).to eq("copy")
    expect(group.fetch("automatic_match")).to include("cannot be matched")
  end

  it "compares resulting users rather than coincidentally equal source and destination IDs" do
    matching_members
    inventory["destination"]["group_memberships"] = [
      { "group_id" => "200", "user_id" => "1" },
      { "group_id" => "200", "user_id" => "2" },
    ]
    expect(
      described_class.build(inventory, described_class.defaults(inventory)).first.fetch("action"),
    ).to eq("copy")
  end

  it "compares sets when multiple source accounts resolve to one destination account" do
    matching_members
    inventory["source"]["group_memberships"] << { "group_id" => "100", "user_id" => "3" }
    inventory["source"]["group_user_matches"] << {
      "source_user_id" => 3,
      "destination_user_id" => 9,
    }
    expect(
      described_class.build(inventory, described_class.defaults(inventory)).first.fetch("action"),
    ).to eq("reuse")
  end

  it "allows explicitly keeping an identical group separate" do
    matching_members
    rows = described_class.defaults(inventory)
    rows.first["action"] = "copy"
    expect(described_class.build(inventory, rows).first.fetch("name")).to eq("customers_1")
  end

  it "matches proven empty groups while distinguishing missing membership evidence" do
    inventory["source"]["group_memberships"] = []
    inventory["source"]["group_user_matches"] = []
    inventory["destination"]["group_memberships"] = []
    expect(
      described_class.build(inventory, described_class.defaults(inventory)).first.fetch("action"),
    ).to eq("reuse")
    inventory["destination"].delete("group_memberships")
    expect(
      described_class.build(inventory, described_class.defaults(inventory)).first.fetch("action"),
    ).to eq("copy")
  end

  it "keeps isolated historical bot accounts out of automatic matches" do
    matching_members
    inventory["source"]["group_memberships"] << { "group_id" => "100", "user_id" => "-3" }
    inventory["source"]["group_user_matches"] << {
      "source_user_id" => -3,
      "destination_user_id" => 9,
    }
    expect(
      described_class.build(inventory, described_class.defaults(inventory)).first.fetch("action"),
    ).to eq("copy")
  end

  it "combines permissions when two source grants map to one group" do
    grants = [
      { "origin" => "source", "group_id" => 100, "permission_type" => 3 },
      { "origin" => "source", "group_id" => 101, "permission_type" => 1 },
    ]
    expect(described_class.grants(grants, { 100 => 200, 101 => 200 })).to eq(
      [{ group_id: 200, permission_type: 1 }],
    )
  end
end

RSpec.describe BulkImport::DiscourseMerge::GroupMemberships do
  it "unions incoming members without promoting owners in a reused group" do
    memberships = described_class.new([[200, 10]], [200])
    expect(memberships.add({ "group_id" => "200", "user_id" => "10", "owner" => "t" })).to eq(nil)
    incoming = { "group_id" => "200", "user_id" => "11", "owner" => "t" }
    expect(memberships.add(incoming)).to eq(
      { "group_id" => "200", "user_id" => "11", "owner" => "f" },
    )
    expect(memberships.add(incoming.dup)).to eq(nil)
    copied = { "group_id" => "300", "user_id" => "11", "owner" => "t" }
    expect(memberships.add(copied)).to eq(copied)
  end
end

RSpec.describe BulkImport::DiscourseMerge::AssociationFilter do
  it "preserves existing associations and handles multiple original rows mapping to one key" do
    filter = described_class.new([%w[topic_id group_id]], existing: [[1, 3]])
    expect(filter.accept?({ "topic_id" => "1", "group_id" => "3" })).to be(false)
    expect(filter.accept?({ "topic_id" => 1, "group_id" => 4 })).to be(true)
    expect(filter.accept?({ "topic_id" => "1", "group_id" => "4" })).to be(false)
  end

  it "rejects contradictory incoming permissions after two groups collapse" do
    filter = described_class.new([%w[tag_group_id group_id]], permission: true)
    row = { "tag_group_id" => 1, "group_id" => 4, "permission_type" => 1 }
    expect(filter.accept?(row)).to be(true)
    expect { filter.accept?(row.merge("permission_type" => 2)) }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Conflicting permissions/,
    )
  end
end
