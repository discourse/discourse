# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Wait::V1 do
  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }
  after { sandbox.dispose }

  def build_exec_ctx(configuration, resume_token: nil)
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      configuration: configuration,
      property_schema: described_class.property_schema,
      node_context: {
      },
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox),
      resume_token: resume_token,
    )
  end

  describe "#execute" do
    it "requests a timer wait for interval mode" do
      config = { "resume" => "time_interval", "wait_amount" => 2, "wait_unit" => "hours" }
      exec_ctx = build_exec_ctx(config)

      freeze_time do
        result = described_class.new(configuration: config).execute(exec_ctx)

        expect(exec_ctx).to be_waiting
        expect(exec_ctx.waiting_until).to eq(2.hours.from_now)
        expect(result).to eq([exec_ctx.input_items])
      end
    end

    it "requests an indefinite webhook wait when limit_wait_time is false" do
      config = { "resume" => "webhook" }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-abc")

      described_class.new(configuration: config).execute(exec_ctx)

      expect(exec_ctx).to be_waiting
      expect(exec_ctx.waiting_until).to be_nil
    end

    it "requests a bounded webhook wait when limit_wait_time is true" do
      config = {
        "resume" => "webhook",
        "limit_wait_time" => true,
        "timeout_amount" => 3,
        "timeout_unit" => "hours",
      }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-abc")

      freeze_time do
        described_class.new(configuration: config).execute(exec_ctx)

        expect(exec_ctx).to be_waiting
        expect(exec_ctx.waiting_until).to eq(3.hours.from_now)
      end
    end

    it "raises on a non-positive wait amount" do
      config = { "resume" => "time_interval", "wait_amount" => 0, "wait_unit" => "hours" }
      exec_ctx = build_exec_ctx(config)

      expect { described_class.new(configuration: config).execute(exec_ctx) }.to raise_error(
        ArgumentError,
        /Wait amount/,
      )
    end

    it "raises on an invalid wait unit" do
      config = { "resume" => "time_interval", "wait_amount" => 1, "wait_unit" => "weeks" }
      exec_ctx = build_exec_ctx(config)

      expect { described_class.new(configuration: config).execute(exec_ctx) }.to raise_error(
        ArgumentError,
        /Invalid wait unit/,
      )
    end
  end
end
