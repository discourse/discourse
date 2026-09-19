# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExecutionStat do
  fab!(:workflow, :discourse_workflows_workflow)

  describe ".log" do
    it "creates a row with a single run" do
      described_class.log(workflow.id)

      stat = described_class.find_by(workflow_id: workflow.id, date: Date.current)
      expect(stat.total_runs).to eq(1)
    end

    it "increments total_runs for the same workflow and day" do
      3.times { described_class.log(workflow.id) }

      expect(described_class.where(workflow_id: workflow.id).count).to eq(1)
      expect(described_class.find_by(workflow_id: workflow.id).total_runs).to eq(3)
    end

    it "keeps separate rows per day" do
      described_class.log(workflow.id, date: 2.days.ago.to_date)
      described_class.log(workflow.id, date: Date.current)

      expect(described_class.where(workflow_id: workflow.id).count).to eq(2)
    end
  end

  describe "recording executions" do
    it "logs a run when an execution is created" do
      expect { Fabricate(:discourse_workflows_execution, workflow: workflow) }.to change {
        described_class.where(workflow_id: workflow.id).sum(:total_runs)
      }.by(1)
    end

    it "does not log rate limited executions" do
      expect {
        Fabricate(:discourse_workflows_execution, workflow: workflow, status: :rate_limited)
      }.not_to change { described_class.count }
    end
  end
end
