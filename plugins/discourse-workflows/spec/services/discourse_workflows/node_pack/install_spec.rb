# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodePack::Install do
  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: admin.guardian) }

    fab!(:admin)

    let(:raw_manifest) do
      File.read(Rails.root.join("plugins/discourse-workflows/docs/examples/node-packs/jev.json"))
    end
    let(:params) { { manifest: raw_manifest, approved_destinations: ["https://api.typesafe.ai"] } }

    it "installs immutable effective definitions and is idempotent" do
      expect(result).to run_successfully
      expect(result[:result]).to eq("installed")
      expect(result[:node_pack].definitions.count).to eq(4)
      expect(
        result[:node_pack].definitions.first.definition.dig("_effective", "approved_origins"),
      ).to eq(["https://api.typesafe.ai"])

      repeated = described_class.call(params:, guardian: admin.guardian)
      expect(repeated).to run_successfully
      expect(repeated[:result]).to eq("unchanged")
      expect(DiscourseWorkflows::NodePackDefinition.count).to eq(4)
    end

    it "requires exact destination approval" do
      params[:approved_destinations] = []

      expect(result).to fail_a_policy(:destinations_approved)
      expect(result[:missing]).to eq(["https://api.typesafe.ai"])

      unexpected =
        described_class.call(
          params: {
            manifest: raw_manifest,
            approved_destinations: %w[https://api.typesafe.ai https://extra.example.com],
          },
          guardian: admin.guardian,
        )
      expect(unexpected).to fail_a_policy(:destinations_approved)
      expect(unexpected[:unexpected]).to eq(["https://extra.example.com"])
    end

    it "rejects revision and immutable definition conflicts" do
      expect(result).to run_successfully
      value = JSON.parse(raw_manifest)
      value["description"] = "changed"
      same_revision =
        described_class.call(params: params.merge(manifest: value), guardian: admin.guardian)
      expect(same_revision[:error_type]).to eq("revision_conflict")

      changed_value = JSON.parse(raw_manifest)
      changed_value["version"] = "1.1.0"
      changed_value["nodes"][0]["request"]["body"]["state"] = { "$param" => "question" }
      changed_definition =
        described_class.call(
          params: params.merge(manifest: changed_value),
          guardian: admin.guardian,
        )
      expect(changed_definition[:error_type]).to eq("definition_conflict")
    end

    it "updates the pack revision without changing pinned definitions" do
      expect(result).to run_successfully
      original_definition = result[:node_pack].definitions.find_by!(identifier: "action:jev.choice")
      original_behavior = original_definition.definition.deep_dup
      updated_manifest = JSON.parse(raw_manifest)
      updated_manifest["version"] = "1.1.0"
      updated_manifest["description"] = "Updated pack description"

      updated =
        described_class.call(
          params: params.merge(manifest: updated_manifest),
          guardian: admin.guardian,
        )

      expect(updated).to run_successfully
      expect(updated[:result]).to eq("updated")
      expect(updated[:node_pack].version).to eq("1.1.0")
      expect(original_definition.reload.definition).to eq(original_behavior)
      expect(updated[:node_pack].definitions.count).to eq(4)
    end

    it "adds a node on a new origin without forcing unchanged node versions to change" do
      expect(result).to run_successfully
      updated_manifest = JSON.parse(raw_manifest)
      updated_manifest["version"] = "1.1.0"
      updated_manifest["destinations"] << { "origin" => "https://secondary.example.com" }
      secondary = updated_manifest["nodes"].first.deep_dup
      secondary["key"] = "secondary"
      secondary["request"]["url"] = "https://secondary.example.com/v1/systemone"
      updated_manifest["nodes"] << secondary

      updated =
        described_class.call(
          params: {
            manifest: updated_manifest,
            approved_destinations: %w[https://api.typesafe.ai https://secondary.example.com],
          },
          guardian: admin.guardian,
        )

      expect(updated).to run_successfully
      expect(updated[:node_pack].definitions.count).to eq(5)
      expect(
        updated[:node_pack]
          .definitions
          .find_by!(identifier: "action:jev.choice")
          .definition
          .dig("_effective", "approved_origins"),
      ).to eq(["https://api.typesafe.ai"])
      expect(
        updated[:node_pack]
          .definitions
          .find_by!(identifier: "action:jev.secondary")
          .definition
          .dig("_effective", "approved_origins"),
      ).to eq(["https://secondary.example.com"])
    end

    it "allows credential label-only updates without rewriting definition snapshots" do
      expect(result).to run_successfully
      definition = result[:node_pack].definitions.find_by!(identifier: "action:jev.choice")
      old_label = definition.definition.dig("_effective", "credential", "label")
      updated_manifest = JSON.parse(raw_manifest)
      updated_manifest["version"] = "1.1.0"
      updated_manifest["credentials"][0]["label"] = "Renamed API token"

      updated =
        described_class.call(
          params: params.merge(manifest: updated_manifest),
          guardian: admin.guardian,
        )

      expect(updated).to run_successfully
      expect(updated[:result]).to eq("updated")
      expect(definition.reload.definition.dig("_effective", "credential", "label")).to eq(old_label)
      expect(updated[:node_pack].manifest.dig("credentials", 0, "label")).to eq("Renamed API token")
    end

    it "requires and accepts the cumulative reviewed destination union beyond five origins" do
      origins = 6.times.map { |index| "https://api#{index}.example.com" }
      installed = nil

      origins.each_with_index do |origin, index|
        manifest = cumulative_manifest(version: "1.#{index}.0", origin:, node_key: "node#{index}")
        preview =
          DiscourseWorkflows::NodePack::Preview.call(
            params: {
              manifest:,
            },
            guardian: admin.guardian,
          )
        expected_origins = origins.first(index + 1)
        expect(preview[:preview][:destinations]).to match_array(expected_origins)

        installed =
          described_class.call(
            params: {
              manifest:,
              approved_destinations: expected_origins,
            },
            guardian: admin.guardian,
          )
        expect(installed).to run_successfully
      end

      final_manifest =
        cumulative_manifest(version: "1.6.0", origin: origins.last, node_key: "node6")
      rejected =
        described_class.call(
          params: {
            manifest: final_manifest,
            approved_destinations: origins.first(5),
          },
          guardian: admin.guardian,
        )

      expect(installed[:node_pack].definitions.count).to eq(6)
      expect(rejected).to fail_a_policy(:destinations_approved)
      expect(rejected[:missing]).to eq([origins.last])
    end

    it "rejects non-admin callers" do
      user = Fabricate(:user)
      unauthorized = described_class.call(params:, guardian: user.guardian)

      expect(unauthorized).to fail_a_policy(:can_manage_workflows)
    end
  end

  def cumulative_manifest(version:, origin:, node_key:)
    {
      "format" => "discourse-workflows/node-pack",
      "format_version" => 1,
      "key" => "cumulative",
      "version" => version,
      "name" => "Cumulative destinations",
      "destinations" => [{ "origin" => origin }],
      "credentials" => [],
      "nodes" => [
        {
          "key" => node_key,
          "version" => "1.0",
          "label" => node_key,
          "properties" => {
          },
          "request" => {
            "method" => "GET",
            "url" => "#{origin}/data",
            "content_type" => "json",
          },
          "response" => {
          },
        },
      ],
    }
  end
end
