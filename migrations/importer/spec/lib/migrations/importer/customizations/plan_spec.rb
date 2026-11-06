# frozen_string_literal: true

RSpec.describe Migrations::Importer::Customizations::Plan do
  let(:error) { Migrations::Importer::Customizations::Error }

  it "accepts a hand-written plan" do
    plan =
      described_class.new(
        "format_version" => 1,
        "site_settings" => [{ "name" => "title", "target" => "template" }],
        "groups" => [{ "name" => "staff", "target" => "template", "attributes" => ["flair_icon"] }],
        "categories" => [{ "match" => { "slug_path" => "a/b" }, "target" => "skip" }],
        "permalinks" => [
          { "url" => "old/thread", "target" => "migrated", "note" => "redirects to a topic" },
          { "url" => "gone", "target" => "template", "remove" => true },
        ],
      )

    expect(plan.exportable_items("site_settings").size).to eq(1)
    expect(plan.exportable_items("categories")).to be_empty
    expect(plan.exportable_items("permalinks").size).to eq(2)
  end

  it "rejects unknown versions, sections and targets" do
    expect { described_class.new("format_version" => 2) }.to raise_error(error, /format_version/)
    expect { described_class.new("format_version" => 1, "users" => []) }.to raise_error(
      error,
      /users/,
    )
    expect {
      described_class.new(
        "format_version" => 1,
        "site_settings" => [{ "name" => "x", "target" => "both" }],
      )
    }.to raise_error(error, /target must be one of/)
  end

  it "requires the natural key of each item" do
    expect {
      described_class.new("format_version" => 1, "categories" => [{ "target" => "migrated" }])
    }.to raise_error(error, /match is required/)
    expect {
      described_class.new(
        "format_version" => 1,
        "translation_overrides" => [{ "locale" => "en", "target" => "migrated" }],
      )
    }.to raise_error(error, /locale and key/)
    expect {
      described_class.new("format_version" => 1, "permalinks" => [{ "target" => "template" }])
    }.to raise_error(error, /url is required/)
  end
end
