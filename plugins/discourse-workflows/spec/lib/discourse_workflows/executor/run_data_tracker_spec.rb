# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::RunDataTracker do
  let(:tracker) { described_class.new }

  def build_step(node_id:, status: "running", **kwargs)
    DiscourseWorkflows::Executor::Step.new(
      node_id: node_id,
      node_name: "Node #{node_id}",
      node_type: "action:code",
      position: 0,
      input: [],
      status: status,
      **kwargs,
    )
  end

  describe "#record_step" do
    it "records steps under the given node name" do
      step = build_step(node_id: "1", status: "success")
      tracker.record_step("my_node", step)

      expect(tracker.data["my_node"]).to eq([step])
    end

    it "appends multiple steps for the same node" do
      step1 = build_step(node_id: "1", status: "running")
      step2 = build_step(node_id: "1", status: "success")
      tracker.record_step("my_node", step1)
      tracker.record_step("my_node", step2)

      expect(tracker.data["my_node"]).to eq([step1, step2])
    end
  end

  describe "#find_step" do
    before do
      tracker.record_step("node_a", build_step(node_id: "1", status: "running"))
      tracker.record_step("node_a", build_step(node_id: "1", status: "success"))
      tracker.record_step("node_b", build_step(node_id: "2", status: "success"))
    end

    it "finds a step by node_id" do
      found = tracker.find_step(node_id: "2")
      expect(found.node_id).to eq("2")
    end

    it "finds a step by node_id and status" do
      found = tracker.find_step(node_id: "1", status: "success")
      expect(found.node_id).to eq("1")
      expect(found).to be_success
    end

    it "returns nil when no match" do
      expect(tracker.find_step(node_id: "999")).to be_nil
    end
  end

  describe "#update_step!" do
    it "updates a matching step in place" do
      step = build_step(node_id: "1", status: "waiting")
      tracker.record_step("my_node", step)

      tracker.update_step!(
        node_id: "1",
        from_status: "waiting",
        updates: {
          "status" => "success",
          "output" => [{ "json" => {} }],
        },
      )

      expect(step).to be_success
      expect(step.output).to eq([{ "json" => {} }])
    end

    it "returns nil when no matching step" do
      result = tracker.update_step!(node_id: "999", from_status: "waiting", updates: {})
      expect(result).to be_nil
    end
  end

  describe "#last_failed_step" do
    it "returns the last step with error status" do
      tracker.record_step("node_a", build_step(node_id: "1", status: "success"))
      tracker.record_step("node_a", build_step(node_id: "2", status: "error"))
      tracker.record_step("node_b", build_step(node_id: "3", status: "success"))

      expect(tracker.last_failed_step.node_id).to eq("2")
    end

    it "returns nil when no failed steps" do
      tracker.record_step("node_a", build_step(node_id: "1", status: "success"))
      expect(tracker.last_failed_step).to be_nil
    end
  end

  describe "#total_steps" do
    it "returns 0 when empty" do
      expect(tracker.total_steps).to eq(0)
    end

    it "counts all steps across all nodes" do
      tracker.record_step("node_a", build_step(node_id: "1"))
      tracker.record_step("node_a", build_step(node_id: "1"))
      tracker.record_step("node_b", build_step(node_id: "2"))

      expect(tracker.total_steps).to eq(3)
    end
  end

  describe "#serializable_data" do
    it "returns hash representation of all steps" do
      tracker.record_step("node_a", build_step(node_id: "1", status: "success"))
      data = tracker.serializable_data

      expect(data["node_a"].first).to be_a(Hash)
      expect(data["node_a"].first["node_id"]).to eq("1")
      expect(data["node_a"].first["status"]).to eq("success")
    end
  end

  describe "initialization with existing data" do
    it "wraps raw hashes as Step objects" do
      existing = {
        "node_a" => [
          {
            "node_id" => "1",
            "status" => "success",
            "node_name" => "A",
            "node_type" => "action:code",
            "position" => 0,
            "input" => [],
          },
        ],
      }
      tracker = described_class.new(existing)

      found = tracker.find_step(node_id: "1")
      expect(found).to be_a(DiscourseWorkflows::Executor::Step)
      expect(found).to be_success
      expect(tracker.total_steps).to eq(1)
    end
  end
end
