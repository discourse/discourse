# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeTypeSerializer do
  describe "#to_h" do
    it "serializes output contract schemas by version", :aggregate_failures do
      serializer = described_class.new(identifier: "action:group", available_versions: ["1.0"])

      version = serializer.to_h.dig(:versions, "1.0")

      expect(version.dig(:output_contracts, 0, :schema)).to eq({})
      expect(version.dig(:output_contracts, 0, :mode)).to eq(:replace)
      expect(version.dig(:output_contracts, 0, :variants)).to eq(
        [
          {
            schema:
              DiscourseWorkflows::Schema.merge(
                DiscourseWorkflows::Schema::GROUP_SCHEMA,
                DiscourseWorkflows::Schema::BASIC_USER_SCHEMA,
              ),
            mode: :replace,
            display_options: {
              show: {
                operation: %w[add remove],
              },
            },
          },
          {
            schema: DiscourseWorkflows::Schema::GROUP_SCHEMA,
            mode: :replace,
            display_options: {
              show: {
                operation: ["get"],
              },
            },
          },
          {
            schema: DiscourseWorkflows::Schema::GROUP_MEMBERSHIP_SCHEMA,
            mode: :merge,
            display_options: {
              show: {
                operation: ["check_membership"],
              },
            },
          },
        ],
      )
    end

    it "omits empty and default declaration fields", :aggregate_failures do
      serializer = described_class.new(identifier: "trigger:manual", available_versions: ["1.0"])

      version = serializer.to_h.dig(:versions, "1.0")

      expect(version).not_to have_key(:output_contracts)
    end

    it "serializes a non-default mode without an output schema" do
      serializer = described_class.new(identifier: "action:limit", available_versions: ["1.0"])

      version = serializer.to_h.dig(:versions, "1.0")

      expect(version[:output_contracts]).to contain_exactly(
        schema: {
        },
        mode: :passthrough,
        display_options: {
        },
        variants: [],
      )
    end

    it "serializes configuration-aware output variants" do
      serializer = described_class.new(identifier: "flow:wait", available_versions: ["1.0"])

      version = serializer.to_h.dig(:versions, "1.0")

      expect(version.dig(:output_contracts, 0, :variants)).to contain_exactly(
        {
          schema: DiscourseWorkflows::Schema::WEBHOOK_REQUEST_SCHEMA,
          mode: :union,
          display_options: {
            show: {
              resume: ["webhook"],
              limit_wait_time: [true],
              timeout_amount: [{ condition: { exists: true } }],
            },
          },
        },
        {
          schema: DiscourseWorkflows::Schema::WEBHOOK_REQUEST_SCHEMA,
          mode: :replace,
          display_options: {
            show: {
              resume: ["webhook"],
            },
          },
        },
      )
    end

    it "marks hidden executable definitions for client-side palette filtering" do
      serializer =
        described_class.new(identifier: "flow:loop_over_items", available_versions: ["1.0"])

      version = serializer.to_h.dig(:versions, "1.0")

      expect(version[:palette_visible]).to eq(false)
      expect(version[:output_contracts].pluck(:mode)).to eq(%i[passthrough passthrough])
    end
  end
end
