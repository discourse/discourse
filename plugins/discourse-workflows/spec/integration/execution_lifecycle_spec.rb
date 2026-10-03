# frozen_string_literal: true

RSpec.describe "Workflow execution lifecycle" do
  let(:effect_url) { "https://workflow.example.test/effect" }
  let(:checkpoint_url) { "https://workflow.example.test/checkpoint" }
  let(:http_success) do
    {
      status: Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(:ok),
      body: "{}",
      headers: {
        "content-type" => "application/json",
      },
    }
  end
  let(:workflow) { build_workflow }

  def build_workflow
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual"
        yield builder if block_given?
        builder.node "effect-1",
                     "action:http_request",
                     parameters: {
                       method: "POST",
                       url: effect_url,
                     }
        builder.node "checkpoint-1",
                     "action:http_request",
                     parameters: {
                       method: "GET",
                       url: checkpoint_url,
                     }
        builder.chain(*builder.to_h[:nodes].map { |node| node["id"] })
      end
    Fabricate(:discourse_workflows_workflow, published: true, **graph)
  end

  before do
    stub_request(:post, effect_url).to_return(http_success)
    stub_request(:get, checkpoint_url).to_return(http_success)
  end

  describe "wait job ownership" do
    it "keeps a second webhook wait pending when the first callback is redelivered",
       :aggregate_failures do
      waiting_workflow =
        build_workflow do |builder|
          builder.node "wait-1", "flow:wait", parameters: { resume: "webhook" }
          builder.node "wait-2", "flow:wait", parameters: { resume: "webhook" }
        end
      execution = DiscourseWorkflows::Executor.new(waiting_workflow, "trigger-1", {}).run
      job = Jobs::DiscourseWorkflows::ResumeWebhookWaiting.new
      args = {
        execution_id: execution.id,
        resume_token: execution.resume_token,
        response_items: [{ "json" => { "approved" => true } }],
      }

      job.execute(args)
      expect(execution.reload.waiting_node_id).to eq("wait-2")
      job.execute(args)

      expect(execution.reload).to have_attributes(status: "waiting", waiting_node_id: "wait-2")
      expect(a_request(:post, effect_url)).not_to have_been_made
    end

    it "keeps a child call pending when an earlier timer is redelivered", :aggregate_failures do
      freeze_time

      target_graph =
        build_workflow_graph { |builder| builder.node "call-trigger", "trigger:workflow_call" }
      target = Fabricate(:discourse_workflows_workflow, published: true, **target_graph)
      parent =
        build_workflow do |builder|
          builder.node "wait-1",
                       "flow:wait",
                       parameters: {
                         resume: "time_interval",
                         wait_amount: 1,
                         wait_unit: "minutes",
                       }
          builder.node "call-1", "action:workflow_call", parameters: { workflow_id: target.id }
        end
      execution = DiscourseWorkflows::Executor.new(parent, "trigger-1", {}).run
      freeze_time(2.minutes.from_now)
      job = Jobs::DiscourseWorkflows::ResumeWaitingExecution.new
      args = { execution_id: execution.id, resume_token: execution.resume_token }

      job.execute(args)
      expect(execution.reload).to have_attributes(waiting_node_id: "call-1", waiting_until: nil)
      job.execute(args)

      expect(execution.reload).to have_attributes(status: "waiting", waiting_node_id: "call-1")
      expect(a_request(:post, effect_url)).not_to have_been_made
    end
  end
end
