# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Wait::V1 do
  def build_exec_ctx(configuration, resume_token: nil)
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      configuration: configuration,
      property_schema: described_class.property_schema,
      node_context: {
      },
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
      resume_token: resume_token,
    )
  end

  describe "#execute" do
    it "returns a timer wait request for interval waits" do
      config = { "resume" => "time_interval", "wait_amount" => 2, "wait_unit" => "hours" }

      freeze_time do
        wait = described_class.new(configuration: config).execute(build_exec_ctx(config))

        expect(wait).to be_a(DiscourseWorkflows::Executor::WaitForResume)
        expect(wait.waiting_config["wait_type"]).to eq("timer")
        expect(wait.waiting_config["wait_amount"]).to eq(2)
        expect(wait.waiting_config["wait_unit"]).to eq("hours")
        expect(wait.waiting_until).to eq(2.hours.from_now)
      end
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

      freeze_time do
        wait =
          described_class.new(configuration: config).execute(
            build_exec_ctx(config, resume_token: "tok-abc"),
          )

        expect(wait).to be_a(DiscourseWorkflows::Executor::WaitForResume)
        expect(wait.waiting_config["wait_type"]).to eq("webhook")
        expect(wait.waiting_config["resume_token"]).to eq("tok-abc")
        expect(wait.waiting_config["http_method"]).to eq("POST")
        expect(wait.waiting_config["response_mode"]).to eq("immediately")
        expect(wait.waiting_config["response_code"]).to eq("202")
        expect(wait.waiting_config["webhook_suffix"]).to eq("after-approval")
        expect(wait.waiting_until).to eq(3.hours.from_now)
      end
    end
  end
end
