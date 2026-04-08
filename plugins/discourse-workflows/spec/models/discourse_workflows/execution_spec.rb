# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution do
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
          node_type: "core:wait",
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
