# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::Extension do
  subject(:extension) { described_class.new(namespace: "run-stats") }

  let(:stats_serializer) do
    Class.new do
      include JSONAPI::Serializer
      set_type :"run-stats"
      attributes :stale
    end
  end
  let(:stats_change) do
    Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
      version "2026-07-08"
      description "Renames a run-stats attribute."

      resource :"run-stats" do
        renamed_attribute from: :outdated, to: :stale
      end
    end
  end

  describe "#register_filter" do
    before { extension.register_filter(:queries, :stale) { |scope, _value| scope } }

    it "namespaces the key automatically" do
      expect(extension.filters_for("queries").keys).to eq(["run-stats.stale"])
    end

    it "exposes no filters for other types" do
      expect(extension.filters_for("users")).to be_empty
    end
  end

  describe "#register_relationship" do
    before { extension.register_relationship(:queries, serializer: stats_serializer) { nil } }

    it "owns the type introduced by the serializer" do
      expect(extension.owned_types).to eq(["run-stats"])
    end

    it "attaches to the target type" do
      expect(extension.attached_types).to eq(["queries"])
    end
  end

  describe "#register_version_change" do
    before { extension.register_version_change(stats_change) }

    it "collects the change" do
      expect(extension.version_changes).to eq([stats_change])
    end
  end

  describe "#filter_renames_on" do
    let(:renaming_change) do
      Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
        version "2026-06-20"
        description "Renames a run-stats filter."

        resource :"run-stats" do
          renamed_filter from: :outdated, to: :stale
        end
      end
    end

    before do
      extension.register_relationship(:queries, serializer: stats_serializer) { nil }
      extension.register_version_change(renaming_change)
    end

    it "projects the rename onto the attached surface with both sides prefixed" do
      expect(extension.filter_renames_on("queries", change: renaming_change)).to eq(
        "run-stats.outdated": :"run-stats.stale",
      )
    end

    it "projects nothing onto types it is not attached to" do
      expect(extension.filter_renames_on("users", change: renaming_change)).to be_empty
    end

    it "projects nothing for a change it does not ship" do
      expect(extension.filter_renames_on("queries", change: stats_change)).to be_empty
    end
  end
end
