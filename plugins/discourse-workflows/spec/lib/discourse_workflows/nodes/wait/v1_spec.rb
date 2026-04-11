# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Wait::V1 do
  def build_exec_ctx(configuration)
    DiscourseWorkflows::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      configuration: configuration,
      configuration_schema: described_class.configuration_schema,
      node_context: {
      },
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
    )
  end

  describe "#execute" do
    it "returns a timer wait request for interval waits" do
      config = { "resume" => "time_interval", "wait_amount" => 2, "wait_unit" => "hours" }

      wait = described_class.new(configuration: config).execute(build_exec_ctx(config))

      expect(wait).to be_a(DiscourseWorkflows::WaitForTimer)
      expect(wait.wait_amount).to eq(2)
      expect(wait.wait_unit).to eq("hours")
      expect(wait.wait_duration_seconds).to eq(2.hours.to_i)
    end

    it "returns a webhook wait request for webhook waits" do
      config = {
        "resume" => "webhook",
        "http_method" => "POST",
        "response_mode" => "immediately",
        "response_code" => "202",
        "webhook_suffix" => "after-approval",
        "limit_wait_time" => true,
        "timeout_amount" => 3,
        "timeout_unit" => "hours",
      }

      wait = described_class.new(configuration: config).execute(build_exec_ctx(config))

      expect(wait).to be_a(DiscourseWorkflows::WaitForWebhook)
      expect(wait.http_method).to eq("POST")
      expect(wait.response_mode).to eq("immediately")
      expect(wait.response_code).to eq("202")
      expect(wait.webhook_suffix).to eq("after-approval")
      expect(wait.timeout_seconds).to eq(3.hours.to_i)
    end
  end
end
