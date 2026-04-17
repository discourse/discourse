# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::PluginEnableHandler do
  describe ".handle!" do
    it "reschedules waiting executions that have a waiting_until" do
      workflow = Fabricate(:discourse_workflows_workflow, enabled: true)
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

    it "restarts seconds chains for enabled workflows with seconds rules" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:schedule",
                 configuration: {
                   "rules" => [{ "interval" => "seconds", "seconds_between_triggers" => 10 }],
                 }
        end
      workflow = Fabricate(:discourse_workflows_workflow, enabled: true, **graph)

      disabled_graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:schedule",
                 configuration: {
                   "rules" => [{ "interval" => "seconds", "seconds_between_triggers" => 10 }],
                 }
        end
      Fabricate(:discourse_workflows_workflow, enabled: false, **disabled_graph)

      Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.clear

      described_class.handle!

      enqueued = Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs
      expect(enqueued.size).to eq(1)
      expect(enqueued.first["args"].first["workflow_id"]).to eq(workflow.id)
    end

    it "skips non-seconds rules" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:schedule",
                 configuration: {
                   "rules" => [{ "interval" => "minutes", "minutes_between_triggers" => 5 }],
                 }
        end
      Fabricate(:discourse_workflows_workflow, enabled: true, **graph)

      Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.clear

      described_class.handle!

      expect(Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs).to be_empty
    end
  end
end
