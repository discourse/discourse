# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::NodeExecutionContext do
  describe "#get_parameters" do
    it "resolves $json expressions against the item passed in, not a cached first item" do
      config = { "value" => "={{ $json.x }}" }
      schema = { value: { type: :string } }
      resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} })

      ctx =
        described_class.new(
          input_items: [],
          configuration: config,
          property_schema: schema,
          resolver: resolver,
        )

      first = ctx.get_parameters({ "json" => { "x" => "ITEM_ONE" } })
      second = ctx.get_parameters({ "json" => { "x" => "ITEM_TWO" } })

      expect(first).to eq("value" => "ITEM_ONE")
      expect(second).to eq("value" => "ITEM_TWO")
    end
  end
end
