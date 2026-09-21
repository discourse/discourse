# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodePacks::CanonicalJson do
  describe ".behavior_sha256" do
    it "excludes plain option labels but retains their values" do
      definition = {
        "properties" => {
          "choice" => {
            "type" => "options",
            "options" => [{ "value" => "alpha", "label" => "Alpha" }],
          },
        },
      }
      relabeled = definition.deep_dup
      relabeled.dig("properties", "choice", "options", 0)["label"] = "Renamed alpha"
      changed_value = definition.deep_dup
      changed_value.dig("properties", "choice", "options", 0)["value"] = "beta"

      expect(described_class.behavior_sha256(relabeled)).to eq(
        described_class.behavior_sha256(definition),
      )
      expect(described_class.behavior_sha256(changed_value)).not_to eq(
        described_class.behavior_sha256(definition),
      )
    end
  end
end
