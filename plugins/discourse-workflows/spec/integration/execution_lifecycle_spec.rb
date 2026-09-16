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

  describe "job interruption and redelivery" do
    it "records an interrupted manual execution after redelivery", :aggregate_failures do
      stub_request(:get, checkpoint_url).to_raise(Sidekiq::Shutdown).then.to_return(http_success)
      execution =
        DiscourseWorkflows::Execution.create_pending_manual!(
          workflow:,
          trigger_node_id: "trigger-1",
          trigger_data: {
          },
        )
      job = Jobs::DiscourseWorkflows::ExecuteManualWorkflow.new
      args = {
        execution_id: execution.id,
        current_site_id: RailsMultisite::ConnectionManagement.current_db,
      }

      expect { job.perform(args) }.to raise_error(Sidekiq::Shutdown)
      job.perform(args)

      expect(execution.reload).to have_attributes(status: "error", finished_at: be_present)
      expect(workflow.executions.count).to eq(1)
      expect(a_request(:post, effect_url)).to have_been_made.once
      expect(execution.execution_data.steps_array.last["status"]).to eq("error")
    end

    it "preserves one execution and one external effect when a regular job is redelivered",
       :aggregate_failures do
      error_graph = build_workflow_graph { |builder| builder.node "error-1", "trigger:error" }
      error_workflow = Fabricate(:discourse_workflows_workflow, published: true, **error_graph)
      workflow.update!(error_workflow_id: error_workflow.id)
      stub_request(:get, checkpoint_url).to_raise(Sidekiq::Shutdown).then.to_return(http_success)
      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.new
      job.jid = "workflow-redelivery"
      args = {
        workflow_id: workflow.id,
        trigger_node_id: "trigger-1",
        current_site_id: RailsMultisite::ConnectionManagement.current_db,
      }

      expect { job.perform(args) }.to raise_error(Sidekiq::Shutdown)
      job.perform(args)

      expect(workflow.executions.count).to eq(1)
      expect(workflow.executions.where(status: :running)).to be_empty
      expect(a_request(:post, effect_url)).to have_been_made.once
      expect(
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.sole["args"].first["workflow_id"],
      ).to eq(error_workflow.id)
    end

    it "retries when shutdown interrupts execution creation" do
      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.new
      job.jid = "workflow-interrupted-creation"
      args = {
        workflow_id: workflow.id,
        trigger_node_id: "trigger-1",
        current_site_id: RailsMultisite::ConnectionManagement.current_db,
      }
      creation_attempts = 0
      interrupt_creation = -> { raise Sidekiq::Shutdown if (creation_attempts += 1) == 1 }
      DiscourseWorkflows::Execution.set_callback(:create, :before, interrupt_creation)

      expect { job.perform(args) }.to raise_error(Sidekiq::Shutdown)
      expect(workflow.executions).to be_empty
      job.perform(args)

      expect(workflow.executions.sole).to be_success
      expect(a_request(:post, effect_url)).to have_been_made.once
    ensure
      DiscourseWorkflows::Execution.skip_callback(:create, :before, interrupt_creation)
    end

    it "records an interrupted resumed execution after redelivery", :aggregate_failures do
      freeze_time

      waiting_workflow =
        build_workflow do |builder|
          builder.node "wait-1",
                       "flow:wait",
                       parameters: {
                         resume: "time_interval",
                         wait_amount: 1,
                         wait_unit: "minutes",
                       }
        end
      execution = DiscourseWorkflows::Executor.new(waiting_workflow, "trigger-1", {}).run
      freeze_time(2.minutes.from_now)
      stub_request(:get, checkpoint_url).to_raise(Sidekiq::Shutdown).then.to_return(http_success)
      job = Jobs::DiscourseWorkflows::ResumeWaitingExecution.new
      args = {
        execution_id: execution.id,
        resume_token: execution.resume_token,
        current_site_id: RailsMultisite::ConnectionManagement.current_db,
      }

      expect { job.perform(args) }.to raise_error(Sidekiq::Shutdown)
      job.perform(args)

      expect(execution.reload).to have_attributes(status: "error", finished_at: be_present)
      expect(a_request(:post, effect_url)).to have_been_made.once
    end

    it "records shutdown while saving a waiting checkpoint" do
      waiting_workflow =
        build_workflow do |builder|
          builder.node "wait-1", "flow:wait", parameters: { resume: "webhook" }
        end
      checkpoint_saves = 0
      interrupt_checkpoint = -> { raise Sidekiq::Shutdown if (checkpoint_saves += 1) == 1 }
      DiscourseWorkflows::ExecutionData.set_callback(:save, :before, interrupt_checkpoint)

      expect do
        Jobs::DiscourseWorkflows::ExecuteWorkflow.new.perform(
          workflow_id: waiting_workflow.id,
          trigger_node_id: "trigger-1",
          current_site_id: RailsMultisite::ConnectionManagement.current_db,
        )
      end.to raise_error(Sidekiq::Shutdown)

      expect(waiting_workflow.executions.sole).to have_attributes(
        status: "error",
        finished_at: be_present,
      )
    ensure
      DiscourseWorkflows::ExecutionData.skip_callback(:save, :before, interrupt_checkpoint)
    end
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
