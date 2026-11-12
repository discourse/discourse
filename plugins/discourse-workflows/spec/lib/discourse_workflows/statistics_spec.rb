# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Statistics do
  before { freeze_time(Time.utc(2026, 6, 15, 12, 0)) }

  fab!(:user)

  describe ".total" do
    it "counts every workflow" do
      Fabricate(:discourse_workflows_workflow)
      Fabricate(:discourse_workflows_workflow)

      expect(described_class.total).to eq(count: 2)
    end
  end

  describe ".created" do
    it "counts workflows created within each window" do
      Fabricate(:discourse_workflows_workflow)
      Fabricate(:discourse_workflows_workflow).update_columns(created_at: 10.days.ago)
      Fabricate(:discourse_workflows_workflow).update_columns(created_at: 45.days.ago)

      expect(described_class.created).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 2,
        previous_30_days: 1,
      )
    end
  end

  describe ".edited" do
    it "counts distinct workflows edited beyond their initial snapshot" do
      recently_edited = Fabricate(:discourse_workflows_workflow, created_by: user)
      recently_edited.snapshot!(user: user)

      previously_edited = Fabricate(:discourse_workflows_workflow, created_by: user)
      previously_edited.snapshot!(user: user)
      DiscourseWorkflows::WorkflowVersion
        .where(workflow_id: previously_edited.id)
        .where("version_number > 1")
        .update_all(created_at: 45.days.ago)

      # never edited beyond creation - must not be counted
      Fabricate(:discourse_workflows_workflow, created_by: user)

      expect(described_class.edited).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 1,
        previous_30_days: 1,
      )
    end
  end

  describe ".executed" do
    it "counts distinct workflows with runs in each window" do
      one = Fabricate(:discourse_workflows_workflow)
      two = Fabricate(:discourse_workflows_workflow)

      DiscourseWorkflows::ExecutionStat.create!(
        workflow_id: one.id,
        date: Date.current,
        total_runs: 3,
      )
      DiscourseWorkflows::ExecutionStat.create!(
        workflow_id: one.id,
        date: 10.days.ago.to_date,
        total_runs: 2,
      )
      DiscourseWorkflows::ExecutionStat.create!(
        workflow_id: two.id,
        date: 45.days.ago.to_date,
        total_runs: 5,
      )

      expect(described_class.executed).to eq(
        last_day: 1,
        "7_days": 1,
        "30_days": 1,
        previous_30_days: 1,
      )
    end
  end

  describe ".executions" do
    it "sums runs in each window plus a lifetime count" do
      workflow = Fabricate(:discourse_workflows_workflow)

      DiscourseWorkflows::ExecutionStat.create!(
        workflow_id: workflow.id,
        date: Date.current,
        total_runs: 3,
      )
      DiscourseWorkflows::ExecutionStat.create!(
        workflow_id: workflow.id,
        date: 10.days.ago.to_date,
        total_runs: 2,
      )
      DiscourseWorkflows::ExecutionStat.create!(
        workflow_id: workflow.id,
        date: 45.days.ago.to_date,
        total_runs: 5,
      )

      expect(described_class.executions).to eq(
        last_day: 3,
        "7_days": 3,
        "30_days": 5,
        previous_30_days: 5,
        count: 10,
      )
    end
  end
end
