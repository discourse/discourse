# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TriggerNodeContext do
  describe "#get_node_parameter" do
    it "reads top-level and nested parameters" do
      ctx =
        described_class.new(
          {
            "parameters" => {
              "category_id" => "1",
              "rules" => [{ "tag_names" => %w[bug urgent] }],
            },
          },
        )

      expect(ctx.get_node_parameter("category_id")).to eq("1")
      expect(ctx.get_node_parameter("rules.0.tag_names")).to eq(%w[bug urgent])
    end

    it "returns the default for missing parameters" do
      ctx = described_class.new({ "parameters" => {} })

      expect(ctx.get_node_parameter("hours", 24)).to eq(24)
    end
  end
end
