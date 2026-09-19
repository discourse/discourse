# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution do
  describe ".claim_for_resume" do
    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:execution) do
      Fabricate(
        :discourse_workflows_execution,
        workflow: workflow,
        status: :waiting,
        resume_token: "tok-abc",
      )
    end

    it "transitions a waiting execution to running and returns it" do
      claimed = described_class.claim_for_resume(execution, resume_token: "tok-abc")

      expect(claimed).to be_present
      expect(claimed.status).to eq("running")
      expect(execution.reload.status).to eq("running")
    end

    it "returns nil when the resume token does not match" do
      expect(described_class.claim_for_resume(execution, resume_token: "wrong")).to be_nil
      expect(execution.reload.status).to eq("waiting")
    end

    it "returns nil when the execution is no longer waiting" do
      execution.update!(status: :running)

      expect(described_class.claim_for_resume(execution, resume_token: "tok-abc")).to be_nil
    end

    it "returns nil when the execution does not exist" do
      execution.destroy!

      expect(described_class.claim_for_resume(execution, resume_token: "tok-abc")).to be_nil
    end

    it "matches without a resume token (job entry points)" do
      claimed = described_class.claim_for_resume(execution)

      expect(claimed).to be_present
      expect(claimed.status).to eq("running")
    end

    it "is idempotent — only the first call claims the execution" do
      first = described_class.claim_for_resume(execution, resume_token: "tok-abc")
      second = described_class.claim_for_resume(execution, resume_token: "tok-abc")

      expect(first).to be_present
      expect(second).to be_nil
    end
  end

  describe ".claim_pending" do
    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:execution) do
      Fabricate(:discourse_workflows_execution, workflow: workflow, status: :pending)
    end

    it "transitions a pending execution to running and returns it" do
      claimed = described_class.claim_pending(execution)

      expect(claimed).to be_present
      expect(claimed.status).to eq("running")
      expect(claimed.started_at).to be_present
      expect(execution.reload.status).to eq("running")
    end

    it "returns nil when the execution is no longer pending" do
      execution.update!(status: :running)

      expect(described_class.claim_pending(execution)).to be_nil
    end
  end

  describe "#fail_with_timeout!" do
    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:execution) do
      Fabricate(
        :discourse_workflows_execution,
        workflow: workflow,
        status: :waiting,
        waiting_node_id: "node-1",
        waiting_until: 1.minute.ago,
        resume_token: "tok",
        timeout_action: "fail",
      )
    end

    it "transitions a waiting execution to error and clears waiting fields" do
      messages =
        MessageBus.track_publish("/discourse-workflows/execution/#{execution.id}") do
          expect(execution.fail_with_timeout!).to eq(true)
        end

      execution.reload
      expect(execution).to have_attributes(
        status: "error",
        waiting_node_id: nil,
        waiting_until: nil,
        resume_token: nil,
        timeout_action: nil,
      )
      expect(messages.length).to eq(1)
      expect(messages.first.group_ids).to eq([Group::AUTO_GROUPS[:admins]])
      expect(messages.first.data).to include(type: "execution_progress", refresh: true)
      expect(messages.first.data[:execution]).to include(id: execution.id, status: "error")
    end

    it "returns false and does not transition when the execution is no longer waiting" do
      execution.update!(status: :running)

      expect(execution.fail_with_timeout!).to eq(false)
      expect(execution.reload.status).to eq("running")
    end
  end

  describe ".compute_run_time_ms" do
    def build_step(node_type: "action:code", started_at: nil, finished_at: nil)
      node = Struct.new(:id, :name, :type).new(SecureRandom.uuid, "Node", node_type)
      DiscourseWorkflows::Executor::Step.build(
        node: node,
        position: 0,
        input: [],
        started_at: started_at,
        finished_at: finished_at,
      )
    end

    it "sums durations across multiple steps" do
      steps = [
        build_step(started_at: "2026-01-01T00:00:00.000Z", finished_at: "2026-01-01T00:00:00.150Z"),
        build_step(started_at: "2026-01-01T00:00:00.150Z", finished_at: "2026-01-01T00:00:00.400Z"),
      ]

      expect(described_class.compute_run_time_ms(steps)).to eq(400)
    end

    it "excludes waiting node types" do
      steps = [
        build_step(started_at: "2026-01-01T00:00:00.000Z", finished_at: "2026-01-01T00:00:00.200Z"),
        build_step(
          node_type: "flow:wait",
          started_at: "2026-01-01T00:00:00.200Z",
          finished_at: "2026-01-01T00:05:00.000Z",
        ),
      ]

      expect(described_class.compute_run_time_ms(steps)).to eq(200)
    end

    it "skips steps without finished_at" do
      running_step = build_step(started_at: "2026-01-01T00:00:00.000Z")
      running_step.mark_waiting!

      finished_step =
        build_step(started_at: "2026-01-01T00:00:00.000Z", finished_at: "2026-01-01T00:00:01.000Z")

      expect(described_class.compute_run_time_ms([running_step, finished_step])).to eq(1000)
    end

    it "returns nil when no steps have timing data" do
      step = build_step
      step.mark_waiting!

      expect(described_class.compute_run_time_ms([step])).to be_nil
    end

    it "works with hashes from deserialized execution data" do
      steps = [
        {
          "started_at" => "2026-01-01T00:00:00.000Z",
          "finished_at" => "2026-01-01T00:00:00.500Z",
          "node_type" => "action:code",
        },
      ]

      expect(described_class.compute_run_time_ms(steps)).to eq(500)
    end
  end

  describe ".purge_old" do
    fab!(:workflow, :discourse_workflows_workflow)

    let(:old_time) { 60.days.ago }
    let(:recent_time) { 1.day.ago }

    before { SiteSetting.workflow_executions_retention_days = 30 }

    def fabricate_at(status, created_at)
      execution = Fabricate(:discourse_workflows_execution, workflow: workflow, status: status)
      Fabricate(:discourse_workflows_execution_data, execution: execution)
      described_class.where(id: execution.id).update_all(created_at: created_at)
      execution
    end

    it "deletes old terminal executions and their execution_data" do
      old_success = fabricate_at(:success, old_time)
      old_error = fabricate_at(:error, old_time)
      old_skipped = fabricate_at(:skipped, old_time)
      old_rate_limited = fabricate_at(:rate_limited, old_time)
      recent_success = fabricate_at(:success, recent_time)

      described_class.purge_old

      expect(described_class.where(id: old_success.id)).to be_empty
      expect(described_class.where(id: old_error.id)).to be_empty
      expect(described_class.where(id: old_skipped.id)).to be_empty
      expect(described_class.where(id: old_rate_limited.id)).to be_empty
      expect(described_class.where(id: recent_success.id)).to exist
      expect(
        DiscourseWorkflows::ExecutionData.where(
          execution_id: [old_success.id, old_error.id, old_skipped.id, old_rate_limited.id],
        ),
      ).to be_empty
    end

    it "preserves in-flight statuses even when older than the cutoff" do
      old_waiting = fabricate_at(:waiting, old_time)
      old_running = fabricate_at(:running, old_time)
      old_pending = fabricate_at(:pending, old_time)

      described_class.purge_old

      expect(described_class.where(id: old_waiting.id)).to exist
      expect(described_class.where(id: old_running.id)).to exist
      expect(described_class.where(id: old_pending.id)).to exist
    end

    it "is a no-op when retention is set to 0" do
      SiteSetting.workflow_executions_retention_days = 0
      old_success = fabricate_at(:success, old_time)

      described_class.purge_old

      expect(described_class.where(id: old_success.id)).to exist
    end

    it "batches through more rows than PURGE_BATCH_SIZE" do
      stub_const(DiscourseWorkflows::Execution, :PURGE_BATCH_SIZE, 2) do
        4.times { fabricate_at(:success, old_time) }

        described_class.purge_old

        expect(described_class.where(workflow: workflow, status: :success)).to be_empty
      end
    end
  end
end
