# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::NodeExecutionContext do
  describe "#get_parameters" do
    it "resolves $json expressions against the item passed in, not a cached first item" do
      config = { "value" => "={{ $json.x }}" }
      schema = { value: { type: :string } }
      sandbox = DiscourseWorkflows::JsSandbox.new({ "$json" => {} })
      resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox)

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
    ensure
      resolver&.dispose
      sandbox&.dispose
    end
  end

  describe "#put_execution_to_wait" do
    it "defaults to not waiting" do
      ctx = described_class.new(input_items: [], resolver: nil)
      expect(ctx).not_to be_waiting
      expect(ctx.waiting_until).to be_nil
    end

    it "flags the context as waiting with the given deadline" do
      ctx = described_class.new(input_items: [], resolver: nil)
      deadline = 2.hours.from_now

      ctx.put_execution_to_wait(deadline)

      expect(ctx).to be_waiting
      expect(ctx.waiting_until).to eq(deadline)
    end

    it "accepts a nil deadline to request the executor ceiling" do
      ctx = described_class.new(input_items: [], resolver: nil)

      ctx.put_execution_to_wait(nil)

      expect(ctx).to be_waiting
      expect(ctx.waiting_until).to be_nil
    end
  end
end
