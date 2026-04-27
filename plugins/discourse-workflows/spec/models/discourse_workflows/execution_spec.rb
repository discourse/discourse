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
      claimed = described_class.claim_for_resume(id: execution.id, resume_token: "tok-abc")

      expect(claimed).to be_present
      expect(claimed.status).to eq("running")
      expect(execution.reload.status).to eq("running")
    end

    it "returns nil when the resume token does not match" do
      expect(described_class.claim_for_resume(id: execution.id, resume_token: "wrong")).to be_nil
      expect(execution.reload.status).to eq("waiting")
    end

    it "returns nil when the execution is no longer waiting" do
      execution.update!(status: :running)

      expect(described_class.claim_for_resume(id: execution.id, resume_token: "tok-abc")).to be_nil
    end

    it "returns nil when the execution does not exist" do
      expect(described_class.claim_for_resume(id: -1, resume_token: "tok-abc")).to be_nil
    end

    it "matches without a resume token (job entry points)" do
      claimed = described_class.claim_for_resume(id: execution.id)

      expect(claimed).to be_present
      expect(claimed.status).to eq("running")
    end

    it "is idempotent — only the first call claims the execution" do
      first = described_class.claim_for_resume(id: execution.id, resume_token: "tok-abc")
      second = described_class.claim_for_resume(id: execution.id, resume_token: "tok-abc")

      expect(first).to be_present
      expect(second).to be_nil
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
      expect(execution.fail_with_timeout!).to eq(true)

      execution.reload
      expect(execution).to have_attributes(
        status: "error",
        waiting_node_id: nil,
        waiting_until: nil,
        resume_token: nil,
        timeout_action: nil,
      )
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
end
