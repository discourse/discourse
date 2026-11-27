# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/planner"

RSpec.describe BulkImport::DiscourseMerge::Audience do
  fab = ->(group, user) { { "group_id" => group.to_s, "user_id" => user.to_s } }

  let(:inventory) do
    {
      "source" => {
        "account_matches" => [{ "source_user_id" => 1, "destination_user_id" => 21 }],
        "group_memberships" => [fab.call(5, 1), fab.call(5, 2)],
        "private_message_grants" => [{ "topic_id" => "8", "group_id" => "5" }],
        "categories" => [{ "id" => "11", "read_restricted" => "t" }],
        "topics" => [{ "id" => "8" }],
        "grants" => [{ "category_id" => "11", "group_id" => "5" }],
      },
      "destination" => {
        "group_memberships" => [fab.call(6, 21), fab.call(6, 22)],
        "private_message_grants" => [{ "topic_id" => "9", "group_id" => "6" }],
      },
    }
  end
  let(:groups) { [{ "source_group_id" => 5, "action" => "reuse", "destination_group_id" => 6 }] }
  let(:topics) { { 8 => { "action" => "copy_private_message" } } }
  let(:categories) do
    [
      {
        "key" => "new:11",
        "operation" => "retain_source",
        "source_category_id" => 11,
        "access" => "restricted",
        "grants" => [{ "origin" => "source", "group_id" => 5 }],
      },
      {
        "key" => "destination:12",
        "operation" => "preserve_existing",
        "access" => "restricted",
        "grants" => [{ "origin" => "destination", "group_id" => 6 }],
      },
    ]
  end

  it "projects added readers of incoming and existing categories and messages" do
    result = described_class.new(inventory, groups).build(categories, topics)
    expect(result.fetch("memberships")).to eq("6" => %w[destination:21 destination:22 source:2])
    expect(result.fetch("expansions")).to contain_exactly(
      include("side" => "source", "id" => 8, "readers" => ["destination:22"]),
      include("side" => "destination", "id" => 9, "readers" => ["source:2"]),
      include("side" => "source", "key" => "new:11", "readers" => ["destination:22"]),
      include("side" => "destination", "key" => "destination:12", "readers" => ["source:2"]),
    )
  end

  it "omits readers that already have access via direct grants and other groups" do
    inventory.fetch("source").fetch("account_matches") << {
      "source_user_id" => 3,
      "destination_user_id" => 22,
    }
    inventory.fetch("source").fetch("private_message_grants") << {
      "topic_id" => "8",
      "user_id" => "3",
    }
    inventory.fetch("destination").fetch("group_memberships") << fab.call(7, 23)
    inventory.fetch("source").fetch("account_matches") << {
      "source_user_id" => 2,
      "destination_user_id" => 23,
    }
    inventory.fetch("destination").fetch("private_message_grants") << {
      "topic_id" => "9",
      "group_id" => "7",
    }
    result = described_class.new(inventory, groups).build(categories, topics)
    expect(result.fetch("expansions").map { |change| change.fetch("type") }).to eq(
      %w[category category],
    )
  end

  it "needs no approval when the matched groups have identical members" do
    inventory.fetch("source").fetch("account_matches") << {
      "source_user_id" => 2,
      "destination_user_id" => 22,
    }
    access = described_class.new(inventory, groups).build(categories, topics)
    expect(described_class.expands?("group_access" => access)).to eq(false)
  end

  it "projects the destination's existing admin bypass when importing new admins as regular users" do
    inventory.fetch("source").merge!(
      "database" => "source",
      "importable_user_ids" => [1, 2, 3],
      "group_memberships" => [fab.call(70, 1)],
      "grants" => [{ "category_id" => "11", "group_id" => "70" }],
      "content" => {
        "admins" => [1, 3],
        "source_settings" => {
          "suppress_secured_categories_from_admin" => "t",
        },
      },
    )
    inventory.fetch("destination")["content"] = {
      "admins" => [21],
      "settings" => {
        "admin_bypass" => true,
      },
    }
    category = { "access" => "restricted", "destination_category_id" => 12, "grants" => [] }
    topic = { "category_id" => "11" }

    expect(
      described_class.new(inventory, []).publication_readers_preserved?(topic, category, false),
    ).to eq(false)
    audience = described_class.new(inventory, [], preserve_staff_roles: false)
    expect(audience.publication_readers_preserved?(topic, category, false)).to eq(true)
  end
end
