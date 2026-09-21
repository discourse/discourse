# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodePacks::Manifest do
  subject(:result) { described_class.parse(manifest) }

  let(:manifest) do
    File.read(Rails.root.join("plugins/discourse-workflows/docs/examples/node-packs/jev.json"))
  end

  it "accepts and normalizes the shipped Jev example" do
    expect(result).to be_valid
    expect(result.errors).to be_empty
    expect(result.definitions.map { |definition| definition["key"] }).to eq(
      %w[choice score noul batch],
    )
    expect(result.definitions.first.dig("_effective", "credential", "credential_types")).to eq(
      ["bearer_token"],
    )
    expect(result.definitions.first.dig("_effective", "approved_origins")).to eq(
      ["https://api.typesafe.ai"],
    )
  end

  it "rejects unsafe manifest and request capabilities" do
    cases = {
      "unknown_key" => ->(value) { value["surprise"] = true },
      "destination_not_https" => ->(value) do
        value["destinations"][0]["origin"] = "http://example.com"
      end,
      "url_not_in_destinations" => ->(value) do
        value["nodes"][0]["request"]["url"] = "https://other.example/path"
      end,
      "header_forbidden" => ->(value) do
        value["nodes"][0]["request"]["headers"]["Authorization"] = "secret"
      end,
      "expression_default_forbidden" => ->(value) do
        value["nodes"][0]["properties"]["state"]["default"] = "={{ $json.raw }}"
      end,
      "credential_unknown" => ->(value) { value["nodes"][0]["credential"] = "missing" },
      "template_unknown_param" => ->(value) do
        value["nodes"][0]["request"]["body"] = { "$param" => "missing" }
      end,
      "output_schema_invalid" => ->(value) do
        value["nodes"][0]["response"]["output_schema"]["$ref"] = "https://example.com/schema"
      end,
      "output_schema_invalid pattern" => ->(value) do
        value["nodes"][0]["response"]["output_schema"]["properties"]["choice"]["pattern"] = "(a+)+$"
      end,
      "output_schema_invalid combinator" => ->(value) do
        value["nodes"][0]["response"]["output_schema"]["allOf"] = [{ "type" => "object" }]
      end,
      "output_schema_invalid root" => ->(value) do
        value["nodes"][0]["response"]["output_schema"] = {
          "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
          "type" => "string",
        }
      end,
      "version_format" => ->(value) { value["nodes"][0]["version"] = "1.0.0" },
    }

    cases.each do |label, mutation|
      code = label.split.first
      value = JSON.parse(manifest)
      mutation.call(value)
      parsed = described_class.parse(value)
      expect(parsed.errors.map(&:code)).to include(code),
      "expected #{code}: #{parsed.errors.map(&:as_json)}"
    end
  end

  it "rejects duplicate and unsafe object keys" do
    duplicate = manifest.sub('"format_version": 1,', '"format_version": 1, "format_version": 1,')
    expect(described_class.parse(duplicate).errors.map(&:code)).to include("invalid_format")

    unsafe = JSON.parse(manifest)
    unsafe["nodes"][0]["request"]["body"]["__proto__"] = "unsafe"
    expect(described_class.parse(unsafe).errors.map(&:code)).to include("unknown_key")
  end

  it "pins only each node's canonical request origin" do
    value = JSON.parse(manifest)
    value["destinations"] << { "origin" => "https://secondary.example.com" }
    second = value["nodes"].first.deep_dup
    second["key"] = "secondary"
    second["request"]["url"] = "https://secondary.example.com/v1/classify"
    value["nodes"] = [value["nodes"].first, second]

    parsed = described_class.parse(value)

    expect(parsed).to be_valid
    expect(
      parsed.definitions.map { |definition| definition.dig("_effective", "approved_origins") },
    ).to eq([["https://api.typesafe.ai"], ["https://secondary.example.com"]])
  end

  it "hashes effective behavior while ignoring cosmetic text and credential labels" do
    definition = result.definitions.first
    cosmetic = definition.deep_dup
    cosmetic["label"] = "A new label"
    cosmetic["properties"]["state"]["description"] = "New help"
    cosmetic.dig("_effective", "credential")["label"] = "Renamed token"
    changed = definition.deep_dup
    changed["request"]["body"]["state"] = { "$param" => "question" }

    expect(DiscourseWorkflows::NodePacks::CanonicalJson.behavior_sha256(cosmetic)).to eq(
      DiscourseWorkflows::NodePacks::CanonicalJson.behavior_sha256(definition),
    )
    expect(DiscourseWorkflows::NodePacks::CanonicalJson.behavior_sha256(changed)).not_to eq(
      DiscourseWorkflows::NodePacks::CanonicalJson.behavior_sha256(definition),
    )
  end
end
