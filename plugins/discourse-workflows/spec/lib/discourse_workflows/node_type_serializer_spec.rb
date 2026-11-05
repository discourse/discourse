# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeTypeSerializer do
  describe "#to_h" do
    it "does not serialize output contracts" do
      version =
        described_class
          .new(identifier: "action:group", available_versions: ["1.0"])
          .to_h
          .dig(:versions, "1.0")

      expect(version).not_to have_key(:output_contracts)
      expect(version[:description]).not_to have_key(:output_contracts)
    end

    it "marks hidden executable definitions for client-side palette filtering" do
      serializer =
        described_class.new(identifier: "flow:loop_over_items", available_versions: ["1.0"])

      version = serializer.to_h.dig(:versions, "1.0")

      expect(version[:palette_visible]).to eq(false)
    end

    it "serializes the deprecation of superseded versions" do
      register_versioned_workflow_nodes(
        "action:serializer_deprecation_test",
        v1_deprecation: {
          superseded_by: "2.0",
          changes: {
            "editor" => "actor",
          },
          notice_key: "discourse_workflows.node_deprecated.topic_v1",
        },
      )

      serialized =
        described_class.new(
          identifier: "action:serializer_deprecation_test",
          available_versions: %w[1.0 2.0],
        ).to_h

      expect(serialized.dig(:versions, "1.0", :deprecation)).to eq(
        superseded_by: "2.0",
        changes: {
          "editor" => "actor",
        },
        notice_key: "discourse_workflows.node_deprecated.topic_v1",
      )
      expect(serialized.dig(:versions, "2.0")).not_to have_key(:deprecation)
    end
  end
end
