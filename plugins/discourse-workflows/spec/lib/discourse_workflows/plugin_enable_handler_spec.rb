# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::PluginEnableHandler do
  describe ".handle!" do
    it "reschedules waiting executions that have a waiting_until" do
      workflow = Fabricate(:discourse_workflows_workflow, published: true)
      execution =
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :waiting,
          waiting_until: 1.minute.ago,
        )
      Fabricate(
        :discourse_workflows_execution,
        workflow: workflow,
        status: :waiting,
        waiting_until: nil,
      )

      Jobs::DiscourseWorkflows::ResumeWaitingExecution.jobs.clear

      described_class.handle!

      enqueued = Jobs::DiscourseWorkflows::ResumeWaitingExecution.jobs
      expect(enqueued.size).to eq(1)
      expect(enqueued.first["args"].first["execution_id"]).to eq(execution.id)
    end

    it "activates published workflow triggers" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:schedule",
                 configuration: {
                   "rule" => {
                     "interval" => [{ "field" => "minutes", "minutesInterval" => 5 }],
                   },
                 }
        end
      workflow = Fabricate(:discourse_workflows_workflow, published: true, **graph)

      unpublished_graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:schedule",
                 configuration: {
                   "rule" => {
                     "interval" => [{ "field" => "minutes", "minutesInterval" => 5 }],
                   },
                 }
        end
      Fabricate(:discourse_workflows_workflow, published: false, **unpublished_graph)

      DiscourseWorkflows::TriggerRuntime.expects(:activate_workflow!).with(
        workflow,
        workflow_version: workflow.active_version,
      )

      described_class.handle!
    end
  end
end
