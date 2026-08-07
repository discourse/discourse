# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::Plugin do
  subject(:plugin) { described_class.new(namespace: "stats") }

  let(:stats_resource) do
    Class.new(DiscourseDataExplorer::JsonApiKit::ResourceBase) do
      type :stats
      attribute :stale, :boolean
    end
  end
  let(:stats_change) do
    Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
      version "2026-07-08"
      description "Renames a stats attribute."

      resource :stats do
        renamed_attribute from: :outdated, to: :stale
      end
    end
  end

  describe "#register_filter" do
    before do
      plugin.register_filter(:queries, :stale, :boolean, description: "Never run?") do |scope|
        scope
      end
    end

    it "namespaces the key automatically" do
      expect(plugin.filters_for("queries").keys).to eq(["stats.stale"])
    end

    it "records the typed, described declaration" do
      expect(plugin.filters_for("queries")["stats.stale"]).to include(
        type: :boolean,
        description: "Never run?",
      )
    end

    it "exposes no filters for other types" do
      expect(plugin.filters_for("users")).to be_empty
    end

    it "rejects an unknown value type" do
      expect {
        plugin.register_filter(:queries, :fresh, :nonsense, description: "?") { |scope| scope }
      }.to raise_error(ArgumentError)
    end
  end

  describe "#register_relationship" do
    before { plugin.register_relationship(:queries, resource: stats_resource) { nil } }

    it "owns the type introduced by the resource" do
      expect(plugin.owned_types).to eq(["stats"])
    end

    it "attaches to the target type" do
      expect(plugin.attached_types).to eq(["queries"])
    end
  end

  describe "#register_version_change" do
    before { plugin.register_version_change(stats_change) }

    it "collects the change" do
      expect(plugin.version_changes).to eq([stats_change])
    end
  end

  describe "#filter_renames_on" do
    let(:renaming_change) do
      Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
        version "2026-06-20"
        description "Renames a stats filter."

        resource :stats do
          renamed_filter from: :outdated, to: :stale
        end
      end
    end

    before do
      plugin.register_relationship(:queries, resource: stats_resource) { nil }
      plugin.register_version_change(renaming_change)
    end

    it "projects the rename onto the attached surface with both sides prefixed" do
      expect(plugin.filter_renames_on("queries", change: renaming_change)).to eq(
        "stats.outdated": :"stats.stale",
      )
    end

    it "projects nothing onto types it is not attached to" do
      expect(plugin.filter_renames_on("users", change: renaming_change)).to be_empty
    end

    it "projects nothing for a change it does not ship" do
      expect(plugin.filter_renames_on("queries", change: stats_change)).to be_empty
    end
  end
end
