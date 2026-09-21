# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodePack::Preview do
  describe ".call" do
    subject(:result) do
      described_class.call(params: { manifest: incoming_manifest }, guardian: admin.guardian)
    end

    fab!(:admin)

    let(:origin_a) { "https://a.example.com" }
    let(:origin_b) { "https://b.example.com" }
    let(:initial_manifest) { pack_manifest(version: "1.0.0", origin: origin_a, node_key: "alpha") }
    let(:incoming_manifest) { pack_manifest(version: "2.0.0", origin: origin_b, node_key: "beta") }

    before do
      installed =
        DiscourseWorkflows::NodePack::Install.call(
          params: {
            manifest: initial_manifest,
            approved_destinations: [origin_a],
          },
          guardian: admin.guardian,
        )
      @pack = installed[:node_pack]
      DiscourseWorkflows::NodePack::Remove.call(
        params: {
          node_pack_id: @pack.id,
        },
        guardian: admin.guardian,
      )
    end

    it "previews and installs a higher retained-pack revision with the exact destination union" do
      expect(result).to run_successfully
      expect(result[:preview]).to include(
        change: "install",
        destinations: match_array([origin_a, origin_b]),
        installed: include(id: @pack.id, version: "1.0.0", enabled: false),
      )
      expect(result[:preview][:nodes].map { |node| [node[:key], node[:change]] }).to eq(
        [%w[beta new]],
      )
      expect(@pack.reload).to be_removed_at
      expect(@pack.definitions.find_by!(identifier: "action:retained.alpha")).to be_retired_at

      missing_retained_origin =
        DiscourseWorkflows::NodePack::Install.call(
          params: {
            manifest: incoming_manifest,
            approved_destinations: [origin_b],
          },
          guardian: admin.guardian,
        )
      expect(missing_retained_origin).to fail_a_policy(:destinations_approved)
      expect(missing_retained_origin[:missing]).to eq([origin_a])
      expect(@pack.reload).to be_removed_at

      reinstalled =
        DiscourseWorkflows::NodePack::Install.call(
          params: {
            manifest: incoming_manifest,
            approved_destinations: result[:preview][:destinations],
          },
          guardian: admin.guardian,
        )
      expect(reinstalled).to run_successfully
      expect(reinstalled[:result]).to eq("installed")
      expect(@pack.reload.removed_at).to be_nil
      expect(@pack.definitions.active.pluck(:identifier)).to eq(["action:retained.beta"])
    end

    it "detects retained pinned-definition conflicts without reactivation" do
      conflicting_manifest = pack_manifest(version: "2.0.0", origin: origin_a, node_key: "alpha")
      conflicting_manifest.dig("nodes", 0, "request")["url"] = "#{origin_a}/changed"
      preview =
        described_class.call(params: { manifest: conflicting_manifest }, guardian: admin.guardian)

      expect(preview[:preview][:change]).to eq("definition_conflict")
      expect(preview[:preview][:nodes].sole).to include(key: "alpha", change: "conflict")

      install =
        DiscourseWorkflows::NodePack::Install.call(
          params: {
            manifest: conflicting_manifest,
            approved_destinations: [origin_a],
          },
          guardian: admin.guardian,
        )
      expect(install[:error_type]).to eq("definition_conflict")
      expect(@pack.reload).to be_removed_at
      expect(@pack.definitions.active).to be_empty
    end

    it "classifies retained same and lower revisions as install conflicts without reactivation" do
      same_revision =
        described_class.call(params: { manifest: initial_manifest }, guardian: admin.guardian)
      expect(same_revision[:preview][:change]).to eq("revision_conflict")

      same_install =
        DiscourseWorkflows::NodePack::Install.call(
          params: {
            manifest: initial_manifest,
            approved_destinations: [origin_a],
          },
          guardian: admin.guardian,
        )
      expect(same_install[:error_type]).to eq("revision_conflict")

      lower_manifest = pack_manifest(version: "0.9.0", origin: origin_a, node_key: "alpha")
      lower_revision =
        described_class.call(params: { manifest: lower_manifest }, guardian: admin.guardian)
      expect(lower_revision[:preview][:change]).to eq("downgrade")

      lower_install =
        DiscourseWorkflows::NodePack::Install.call(
          params: {
            manifest: lower_manifest,
            approved_destinations: [origin_a],
          },
          guardian: admin.guardian,
        )
      expect(lower_install[:error_type]).to eq("downgrade_not_allowed")
      expect(@pack.reload).to be_removed_at
      expect(@pack.definitions.active).to be_empty
    end
  end

  def pack_manifest(version:, origin:, node_key:)
    {
      "format" => "discourse-workflows/node-pack",
      "format_version" => 1,
      "key" => "retained",
      "version" => version,
      "name" => "Retained pack",
      "destinations" => [{ "origin" => origin }],
      "credentials" => [],
      "nodes" => [
        {
          "key" => node_key,
          "version" => "1.0",
          "label" => node_key.capitalize,
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
